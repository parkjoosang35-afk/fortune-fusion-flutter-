"use client";

// [메뉴 공유 링크 — 즉시 랜딩 리다이렉트]
// `/r/[id]`·`/g/[token]`·`/w/[token]`과 달리 이 공유는 "개인 결과"가 아니라
// "이 서비스를 한번 써보세요"라는 메뉴 자체의 홍보이므로, `/g/[token]`에
// 적용된 "콘텐츠를 먼저 보여주고 앱 전환은 사용자가 스스로 선택할 때만"
// 원칙(대표가 즉시 리다이렉트를 명시적으로 반려한 그 원칙)의 적용 대상이
// 아니다 — 여기엔 "받는 사람만을 위한 개인화된 콘텐츠"가 애초에 없고,
// 사용자의 명시적 요구사항 자체가 "공유 링크를 누르면 ... 해당 메뉴가
// 바로 열리게 해주세요"이다. 따라서 이 페이지는 `/r/[id]`의
// `redirect-to-app.tsx`와 같은 "OG 전용 SSR + 즉시 리다이렉트" 패턴을
// 따르되, 목적지가 `/app/#...`가 아니라 `sintong.kr/?s={menu}`인 점이
// 다르다(PC 랜딩 가운데 iframe에서 그대로 열림, 좌우 안내/전체화면 분기는
// landing-v7.js의 initFromShareParam + CSS 미디어쿼리가 이미 처리).
export function RedirectToLanding({ menu }: { menu: string }) {
  if (typeof window !== "undefined") {
    window.location.replace(`https://sintong.kr/?s=${menu}`);
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
