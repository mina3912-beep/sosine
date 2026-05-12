# Supabase 보안 강화 적용 가이드

## 변경 개요
- 익명 인증(Anonymous Sign-In) 기반 RLS 로 전환
- `plans` / `completions` 는 본인 `owner_id = auth.uid()` 행만 접근
- `signups`(소식 받기) 는 INSERT 만 허용, 익명 SELECT 금지
- 관리자는 Supabase 대시보드(Table Editor / SQL Editor)에서 직접 조회

## 적용 순서

### 1) Supabase 대시보드에서 익명 로그인 활성화
**필수 작업** — 안 켜면 앱 전체가 안 됩니다.
1. Supabase 프로젝트 > **Authentication** > **Sign In / Up**
2. **Anonymous Sign-Ins** 토글 → **ON**
3. (선택) **Rate limit for anonymous sign-ins** 적절히 설정

### 2) SQL 실행
1. Supabase 대시보드 > **SQL Editor**
2. `supabase/schema.sql` 내용 전체 붙여넣고 **Run**
3. "Success. No rows returned." 확인

### 3) 기존 데이터 처리 (선택)
스키마 적용 직후, 기존 행은 `owner_id = null` 이라 RLS 에 막혀
어떤 익명 사용자도 접근할 수 없습니다.

- **그대로 두기**: 기존 사용자는 자동으로 깨끗한 상태로 새 출발
  (로컬 localStorage 진도는 살아있어서 다시 자기 이름으로 시작 가능)
- **싹 비우기**: SQL Editor 에서
  ```sql
  delete from plans;
  delete from completions;
  ```

### 4) 코드 배포
이미 반영된 `index.html` 변경:
- 페이지 로드 시 `supabase.auth.signInAnonymously()` 자동 호출
- 모든 `plans` upsert 에 `owner_id` 포함
- `loadFromSupabase` 가 `owner_id` 필터링

```
git push origin master
vercel deploy --prod --yes
```

## 동작 확인

### 익명 사용자 입장(브라우저 A)
1. 페이지 열기 → 콘솔에 `[Supabase] ✅ 클라이언트 초기화 완료`
2. 이름 입력 후 진도 체크
3. Supabase Table Editor 에서 `plans` 행 확인 → `owner_id` 가 uuid 로 채워져 있어야 함

### 다른 브라우저(브라우저 B)에서 같은 이름 입력
- B 는 다른 `auth.uid()` 를 받으므로, A 의 행을 못 봄
- B 는 자기 owner_id 로 새 행을 만들 수 있어야 함
- 같은 `user_id` 가 두 owner 에 존재해도 PK 충돌이 생기는 점 주의
  → 추가 강화 필요 시 PK 를 `(user_id, owner_id)` 복합키로 변경 고려

### 익명 사용자가 다른 사람 데이터 못 건드리는지
브라우저 콘솔에서:
```js
await window.__supabase.from('plans').select('*');
```
→ 본인 owner_id 행만 반환되어야 함. 다른 사람 행은 안 보임.

### 소식받기 이메일 명단 보호
브라우저 콘솔에서:
```js
await window.__supabase.from('signups').select('*');
```
→ `data: []` (RLS 가 SELECT 금지). PII 유출 없음.

## 관리자 화면(`admin.html`) 영향

현재 `admin.html` 은 anon 키로 `signups` / `plans` 를 SELECT 합니다.
RLS 강화 후 anon 키로는 **전부 비어있게 보여요**. 두 가지 옵션:

### 옵션 A (권장) — Supabase 대시보드에서 직접 조회
- Table Editor 에서 `signups` 열람
- 별도 admin 페이지 없이도 운영 가능

### 옵션 B — service_role 키 분리
- Vercel 환경변수에 `SUPABASE_SERVICE_ROLE_KEY` 추가
- Vercel Serverless Function(예: `api/admin/signups.js`)에서 service_role 로 조회
- `admin.html` 은 그 API 호출
- (코드 추가 필요. 원하면 별도 작업)

지금은 옵션 A 로 두는 게 가장 안전합니다.

## 알아둘 만한 한계

- **새 행 PK 충돌**: 두 사람이 같은 이름("엄마") 으로 등록하면 둘째 사람은
  `plans` PK `user_id` 충돌로 저장 실패할 수 있습니다.
  필요하면 SQL 에서 PK 를 `(user_id, owner_id)` 또는 `owner_id` 단독으로 변경.
- **세션 만료**: 익명 세션은 기본 1시간 만료, refresh 토큰으로 자동 갱신.
  사용자가 캐시·쿠키 삭제하면 새 owner_id 가 되어 진도가 분리됩니다(로컬 localStorage 는 살아있음).
- **세션 탈취**: 누군가 사용자의 JWT 를 탈취하면 그 행은 접근 가능. 이건 대부분의
  익명 인증 모델의 공통 한계.

## 비용 영향
- Supabase Free 플랜 그대로 사용 가능 (Anonymous Auth 포함)
- 추가 과금 없음
