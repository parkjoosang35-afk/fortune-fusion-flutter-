// [귀인지도 v2 — 성장 퍼널 측정 2026-10-13] 웹 랜딩 전용 퍼널 이벤트 헬퍼.
// 기획서(guinji-map-v2-spec §2) 6단 루프 중 웹에서 일어나는 단계만 기록한다:
// share_og_open(링크 오픈) / join_done(참가 완료) / guest_reshare(재공유) /
// app_cta_click(내 지도 만들기 CTA). 익명ID는 localStorage에 1회 발급해
// 재사용 — 개인정보와 무관한 랜덤 문자열이다. 실패해도 UX에 영향 없음(no-op).
const ANON_KEY = "guinji_anon_id";

function anonId(): string {
  try {
    let v = localStorage.getItem(ANON_KEY);
    if (!v || !/^[A-Za-z0-9_-]{8,128}$/.test(v)) {
      v = ("w" + Math.random().toString(36).slice(2) + Date.now().toString(36)).slice(0, 64);
      localStorage.setItem(ANON_KEY, v);
    }
    return v;
  } catch {
    return "wanonymous00000000"; // localStorage 불가(프라이빗 모드 등) — 수집은 계속
  }
}

export function track(eventName: string, mapToken?: string): void {
  try {
    fetch("/api/public/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ eventName, anonymousId: anonId(), ...(mapToken ? { mapToken } : {}) }),
      keepalive: true,
    }).catch(() => {});
  } catch {
    // 이벤트 수집은 부가 기능 — 어떤 경우에도 페이지를 막지 않는다.
  }
}
