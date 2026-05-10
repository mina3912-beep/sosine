/**
 * Supabase 클라이언트 초기화
 * window.__SUPABASE_URL, window.__SUPABASE_ANON_KEY 는
 * Vercel 빌드 시 scripts/build-env.js 가 __env.js 에 주입합니다.
 *
 * 값이 없으면 window.__supabase = null 로 설정되며 앱은 정상 동작합니다.
 * 실제 DB 연동 전에 null 체크 후 사용하세요.
 */
(function () {
  const url = (typeof window !== 'undefined' && window.__SUPABASE_URL) || '';
  const key = (typeof window !== 'undefined' && window.__SUPABASE_ANON_KEY) || '';

  if (!url || !key) {
    window.__supabase = null;
    console.warn(
      '[Supabase] 클라이언트 미초기화 — ' +
      'NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY 를 확인해주세요.'
    );
    return;
  }

  if (typeof window.supabase === 'undefined' || typeof window.supabase.createClient !== 'function') {
    window.__supabase = null;
    console.error('[Supabase] CDN 라이브러리가 로드되지 않았습니다.');
    return;
  }

  try {
    window.__supabase = window.supabase.createClient(url, key);
    console.log('[Supabase] ✅ 클라이언트 초기화 완료');
  } catch (e) {
    window.__supabase = null;
    console.error('[Supabase] 초기화 실패:', e.message);
  }
})();
