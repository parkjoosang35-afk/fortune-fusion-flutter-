"use client";

// [웹 공유 "가짜 페이지" 근본 재설계 — 대표 긴급 지시 반영]
// `/w/[token]`·`/g/[token]`·`/coupon/[token]`과 동일한 "앱·웹 분리" 원칙을
// 그대로 따른다 — 결과 화면(아바타·점수·오행·판정근거까지 포함한 전체
// 레이아웃)은 이미 Flutter 웹앱(`https://sintong.kr/app/`)의 `/r/{shareId}`
// named route(app_router.dart → SharedResultScreen)에 완전히 구현되어 있다.
//
// [과거 구조의 문제 — 반드시 기록] 예전에는 이 경로(`/r/[id]`,
// `/web-result/[id]`)에 admin_web이 자체 제작한 모방 렌더링 페이지
// (ServiceResultView/SharedResultView + SintongBottomNavBar 가짜 하단바
// "홈/운세/소원방/귀인지도/마이")가 있었다. 이는 실제 운영 중인 서비스
// 화면(진짜 하단바 "홈/신당부적/복주머니/마이")과 완전히 다른 모습이었고,
// 대표가 스크린샷 비교로 직접 지적해 전면 삭제가 결정되었다 — 이유는
// Flutter Web이 브라우저 URL을 읽지 않는 구조적 한계를 당시 올바르게
// 해결하지 못하고 "별도 페이지를 또 만드는" 잘못된 우회로 땜질했기
// 때문이다. 이 파일은 그 문제의 근본 해결책(URL을 Flutter 앱이 직접
// 읽어 진짜 화면으로 이동)이다. admin_web에 결과 렌더링 UI를 다시
// 만들지 않는다.
//
// 이 서버(admin_web)의 `/r/{shareId}` 경로가 하는 유일한 역할은 카카오톡
// 등 SNS 크롤러를 위한 OG 미리보기(제목/설명/이미지) 생성뿐이다(크롤러는
// JS를 실행하지 않으므로 Flutter SPA의 동적 내용을 볼 수 없음 — page.tsx의
// generateMetadata() 참고). 실제 사람이 이 링크를 열면 이 컴포넌트가
// 마운트되자마자 즉시 `https://sintong.kr/app/#/r/{shareId}`로 이동한다
// (Flutter 앱은 splash_screen.dart 부팅 로직에서 이 해시를 읽어 바로
// SharedResultScreen으로 push한다).
export function RedirectToApp({ shareId }: { shareId: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/app/#/r/${shareId}`);
  }
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "#0B0B0D",
      }}
    >
      <p style={{ fontSize: 13, color: "#8A8880" }}>신통방통으로 이동하는 중...</p>
    </div>
  );
}
