-- ══════════════════════════════════════════════════════════
--  소시네엄마표영어 — Supabase 스키마 (보안 강화판)
--  Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
--
--  모델:
--   - 각 브라우저는 supabase.auth.signInAnonymously() 로
--     익명 세션을 받고 auth.uid() (uuid) 를 갖는다.
--   - plans/completions 의 owner_id 가 auth.uid() 와 같은
--     행만 본인이 읽고/쓸 수 있다.
--   - signups (소식받기) 는 INSERT 만 익명 허용, SELECT 는 금지
--     (관리자는 Supabase 대시보드/SQL Editor 로 직접 조회).
-- ══════════════════════════════════════════════════════════

-- 0. 익명 인증 활성화 안내 ────────────────────────────────────
--   Authentication > Sign In / Up > Anonymous Sign-Ins 토글을 ON 해야 합니다.
--   (SQL 로는 켤 수 없고 대시보드에서 설정)

-- 1. plans ────────────────────────────────────────────────
create table if not exists plans (
  user_id        text        primary key,
  start_date     timestamptz not null,
  done_days      jsonb       not null default '[]',
  custom_content jsonb       not null default '{}',
  owner_id       uuid,
  updated_at     timestamptz not null default now()
);

-- 기존 테이블에 owner_id 가 없으면 추가
alter table plans add column if not exists owner_id uuid;

alter table plans enable row level security;

-- 옛 정책 제거
drop policy if exists "anon_all_plans" on plans;
drop policy if exists "owner_select_plans" on plans;
drop policy if exists "owner_insert_plans" on plans;
drop policy if exists "owner_update_plans" on plans;
drop policy if exists "owner_delete_plans" on plans;

-- 새 정책: 본인 행만
create policy "owner_select_plans" on plans for select
  to authenticated, anon
  using (owner_id is not null and owner_id = auth.uid());

create policy "owner_insert_plans" on plans for insert
  to authenticated, anon
  with check (owner_id = auth.uid());

create policy "owner_update_plans" on plans for update
  to authenticated, anon
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "owner_delete_plans" on plans for delete
  to authenticated, anon
  using (owner_id = auth.uid());


-- 2. completions ──────────────────────────────────────────
create table if not exists completions (
  user_id      text        not null,
  plan_day     int         not null,
  completed_at timestamptz not null default now(),
  owner_id     uuid,
  primary key (user_id, plan_day)
);

alter table completions add column if not exists owner_id uuid;

alter table completions enable row level security;

drop policy if exists "anon_all_completions" on completions;
drop policy if exists "owner_all_completions" on completions;

create policy "owner_all_completions" on completions for all
  to authenticated, anon
  using (owner_id is not null and owner_id = auth.uid())
  with check (owner_id = auth.uid());


-- 3. signups ──────────────────────────────────────────────
create table if not exists signups (
  id         bigserial   primary key,
  name       text        not null,
  phone      text,
  created_at timestamptz not null default now()
);

alter table signups enable row level security;

-- 옛 정책 제거 (특히 anon_select_signups — 이메일 명단 유출원)
drop policy if exists "anon_insert_signups" on signups;
drop policy if exists "anon_select_signups"  on signups;

-- INSERT 만 익명 허용
create policy "anon_insert_signups" on signups for insert
  to authenticated, anon
  with check (true);

-- SELECT 정책 없음 → 익명 사용자는 신청자 목록을 읽을 수 없음
-- 관리자는 Supabase 대시보드(Table editor) 또는 SQL Editor 에서 조회


-- 4. 기존 데이터 마이그레이션(선택) ─────────────────────────────
-- 새 스키마 적용 직후, owner_id 가 null 인 기존 행은 RLS 에 막혀
-- 어떤 익명 사용자도 접근할 수 없습니다(= 사실상 잠긴 상태).
--
-- 옵션 A) 기존 데이터를 전부 비우고 새로 시작
--   delete from plans;
--   delete from completions;
--
-- 옵션 B) 그대로 두기
--   기존 사용자는 새 익명 세션을 받게 되어 자동으로 깨끗한 상태로 시작.
--   기존 행은 DB 에 남지만 누구도 못 보고 못 지웁니다.
--   필요시 관리자가 SQL Editor 에서 직접 정리.
