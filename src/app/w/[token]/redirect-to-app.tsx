"use client";

// [2026-10, 앱·웹 분리 개발 전면 폐기 — 사용자 명시 지시 재확인, 소원방도 동일 적용]
// 사용자가 격노하며 지적한 핵심 문제: "소원방도 마찬가지, 공유도 마찬가지" —
// 귀인지도와 똑같이, 소원방 초대장도 이미 웹(Flutter 앱)인데 admin_web에
// 커스텀 UI(크림색 배경, "OOO님이 소원방에 초대했어요", ♡응원하기/
// 💬응원메시지/🧧복주머니 버튼, 자체 회원가입 유도 패널)를 통째로 다시
// 만들어 보여주고 있었다 — 사용자가 첨부한 스크린샷이 바로 그 증거다.
//
// [근본 원인] `https://sintong.kr/app/`에는 이미 완전히 동작하는 Flutter
// 웹앱이 배포되어 있고, `/w/{token}` named route(app_router.dart)가 이미
// 존재한다 — LinkInviteScreen(초대장 카드) → "소원방에 들어가기" →
// OtherRoomScreen(실제 소원방: 촛불, 응원·메시지·복주머니 액션)까지 전부
// 이미 구현·검증되어 있다. 응원/복주머니 등 비로그인 사용자 차단도
// AuthTokenStore.authHeader() + 401 응답 처리로 이미 자연스럽게 동작한다
// (WishRoomProvider가 ApiError를 잡아 "로그인이 필요합니다." 토스트를
// 보여준다) — admin_web의 별도 "가입 안내" 게이트 패널은 필요 없었다.
//
// [수정] 이 서버(admin_web)의 `/w/{token}` 경로가 하는 유일한 역할은
// 카카오톡 등 SNS 크롤러에게 OG 미리보기(제목/설명/이미지)를 보여주는
// 것뿐이다(크롤러는 JS를 실행하지 않으므로 generateMetadata()만
// 읽는다 — page.tsx 참고). 실제 사람이 이 링크를 열면, 이 컴포넌트가
// 마운트되자마자 즉시 `https://sintong.kr/app/#/w/{token}`(진짜
// 신통방통 웹, Flutter 빌드)로 이동한다 — 초대장 확인부터 소원방 입장,
// 응원/메시지/복주머니까지 전부 그 하나의 화면 안에서 완결된다.
// admin_web은 더 이상 그 경험을 흉내 내지 않는다.
export function RedirectToApp({ token }: { token: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/app/#/w/${token}`);
  }
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0B0B0D]">
      <p className="text-sm text-[#8A8880]">신통방통으로 이동하는 중...</p>
    </div>
  );
}
