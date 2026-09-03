// [2026-09, 바이럴 디자인 이식] 사용자가 예전에 전달한 "바이럴 디자인"
// 핸드오프 패키지(`nextjs_guiindo`, HANDOFF.md 기준)의 아이보리+로즈골드
// 팔레트·타이포그래피를 이 라우트(`/g/[token]`)에만 적용하기 위한 세그먼트
// 전용 레이아웃. 루트 `layout.tsx`(Geist 폰트, 관리자 대시보드 전역)는
// 손대지 않는다 — 이 파일은 `/g/[token]` 하위 트리에만 영향을 준다.
//
// [폰트] nextjs_guiindo `app/layout.tsx`와 동일한 소스(Noto Serif KR
// Google Fonts + Pretendard Variable jsdelivr CDN)를 그대로 사용해 Flutter
// GmFonts(serif='NotoSerifKR', sans='Pretendard')와 시각적으로 통일한다.
// Next.js는 루트가 아닌 세그먼트 레이아웃에서 렌더링된 <link> 태그도
// 자동으로 <head>로 끌어올려 병합·중복 제거한다(App Router 기본 동작).
export default function GuinjiInviteLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link
        href="https://fonts.googleapis.com/css2?family=Noto+Serif+KR:wght@400;500;600;700;900&display=swap"
        rel="stylesheet"
      />
      <link
        rel="stylesheet"
        as="style"
        crossOrigin="anonymous"
        href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable.min.css"
      />
      <div
        style={{
          fontFamily:
            "'Pretendard Variable', Pretendard, system-ui, sans-serif",
        }}
      >
        {children}
      </div>
    </>
  );
}
