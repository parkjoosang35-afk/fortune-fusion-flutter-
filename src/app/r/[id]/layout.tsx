// [결과 공유 기능] `/r/[id]` 세그먼트 전용 레이아웃. `/g/[token]`의 바이럴
// 디자인(아이보리+로즈골드, Noto Serif KR + Pretendard)을 그대로 재사용해
// 카톡 → 이 랜딩 → 앱까지 이어지는 톤을 통일한다. 루트 layout.tsx(관리자
// 대시보드 전역)는 손대지 않는다.
export default function SharedResultLayout({
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
