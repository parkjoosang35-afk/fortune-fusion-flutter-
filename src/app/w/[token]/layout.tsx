// [소원방 공유 랜딩 신설 — 사용자 리포트 "공유가 엉뚱한 화면으로 감" /
// 카카오 공유 404 버그 수정] `/w/[token]` 세그먼트 전용 레이아웃.
// `/g/[token]`·`/r/[id]`와 동일하게 바이럴 디자인(아이보리+로즈골드,
// Noto Serif KR + Pretendard)을 재사용해 카톡 → 이 랜딩 → 앱까지
// 이어지는 톤을 통일한다. 루트 layout.tsx(관리자 대시보드 전역)는
// 손대지 않는다.
export default function LinkInviteLayout({
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
