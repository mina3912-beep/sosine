-- ══════════════════════════════════════════════════════════
--  소시네엄마표영어 — Supabase 스키마
--  Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ══════════════════════════════════════════════════════════

-- ── 1. plans ─────────────────────────────────────────────
--  학습 플랜 상태 (시작일 · 완료일 목록 · 커스텀 콘텐츠)
create table if not exists plans (
  user_id        text        primary key,
  start_date     timestamptz not null,
  done_days      jsonb       not null default '[]',
  custom_content jsonb       not null default '{}',
  updated_at     timestamptz not null default now()
);

alter table plans enable row level security;

create policy "anon_all_plans"
  on plans for all
  to anon
  using (true)
  with check (true);


-- ── 2. completions ────────────────────────────────────────
--  Day별 완료 기록 (user_id + plan_day 복합 PK)
create table if not exists completions (
  user_id      text        not null,
  plan_day     int         not null,
  completed_at timestamptz not null default now(),
  primary key (user_id, plan_day)
);

alter table completions enable row level security;

create policy "anon_all_completions"
  on completions for all
  to anon
  using (true)
  with check (true);


-- ── 3. signups ────────────────────────────────────────────
--  소식받기 신청자 목록
create table if not exists signups (
  id         bigserial   primary key,
  name       text        not null,
  phone      text,
  created_at timestamptz not null default now()
);

alter table signups enable row level security;

create policy "anon_insert_signups"
  on signups for insert
  to anon
  with check (true);

create policy "anon_select_signups"
  on signups for select
  to anon
  using (true);
