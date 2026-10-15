"use client";

// [2026-10, 앱·웹 분리 개발 전면 폐기 — 사용자 명시 지시 재확인]
// 사용자가 격노하며 지적한 핵심 문제: "지금 하는 건 웹이잖아 — 귀인지도도
// 초대장도 웹이니까, 초대장에서 입력하고 나면 초대장 보낸 사람의 신통방통
// 웹주소로 바로 들어가야 한다"는 것을 여러 번 설명했는데, 대신 admin_web
// (Next.js)에 폼·결과카드·동심원 지도를 통째로 다시 만들어 보여주고
// 있었다 — 정확히 사용자가 첨부한 스크린샷(순수 Next.js 디자인, Flutter
// 앱과 전혀 다른 톤)이 바로 그 증거다.
//
// [근본 원인] `https://sintong.kr/app/`에는 이미 완전히 동작하는 Flutter
// 웹앱이 배포되어 있고, 그 안에 `/g/{token}` named route(app_router.dart)가
// 이미 존재한다 — GuinjiMapGuestJoinScreen(이름·생년월일·시간·성별 입력
// 폼) → GuinjiCalculatingScreen(계산 연출) → GuinjiGuestResultScreen(실제
// 결과: 관계유형·점수·서술, "내 지도 만들기" 선택적 CTA)까지 전부 이미
// 구현·검증되어 있다(2026-09 "2026 디자인 핸드오프" 당시 완성). 즉
// admin_web이 중복으로 다시 만들 필요가 전혀 없었다 — 이게 "왜 이런
// 쉬운 걸 못하냐"는 질책의 실제 원인이다.
//
// [수정] 이 서버(admin_web)의 `/g/{token}` 경로가 하는 유일한 역할은
// 카카오톡 등 SNS 크롤러에게 OG 미리보기(제목/설명/이미지)를 보여주는
// 것뿐이다(크롤러는 JS를 실행하지 않으므로 generateMetadata()만
// 읽는다 — page.tsx 참고). 실제 사람이 이 링크를 열면, 이 컴포넌트가
// 마운트되자마자 즉시 `https://sintong.kr/app/#/g/{token}`(진짜
// 신통방통 웹, Flutter 빌드)로 이동한다 — 입력부터 결과까지 전부 그
// 하나의 화면 안에서 완결된다. admin_web은 더 이상 그 경험을 흉내 내지
// 않는다.
export function RedirectToApp({ token }: { token: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/app/#/g/${token}`);
  }
  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0B0B0D]">
      <p className="text-sm text-[#8A8880]">신통방통으로 이동하는 중...</p>
    </div>
  );
}
