// [복주머니 마케팅 쿠폰] `/coupon/[token]` 세그먼트 전용 레이아웃.
// `/g/[token]`·`/w/[token]`·`/r/[id]`와 동일하게 바이럴 디자인 톤을
// 재사용해 카톡 공유 → 이 랜딩 → 앱까지 이어지는 톤을 통일한다.
// 루트 layout.tsx(관리자 대시보드 전역)는 손대지 않는다.
//
// [2026-10-22, 디자인 핸드오프 — "Midnight Temple(심야의 신전)" 디자인
// 시스템 적용] 사용자가 전달한 `복주머니 모바일 쿠폰.html` / `colors_and_
// type.css` 레퍼런스가 요구하는 폰트 묶음(Noto Serif KR 900=브랜드/금액,
// Gowun Batang 700=티켓 타입/브랜드명, Pretendard=UI 칩/버튼,
// IBM Plex Mono=메타 라벨/시리얼) 전체를 로드한다. 기존 Pretendard만
// 쓰던 단순 카드 디자인에서 풍부한 티켓 디자인으로 교체하며 추가된 폰트.
export default function BokjuCouponLandingLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link
        href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=Noto+Serif+KR:wght@400;600;900&family=IBM+Plex+Mono:wght@400;500&display=swap"
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
          fontFamily: "'Pretendard Variable', Pretendard, system-ui, sans-serif",
        }}
      >
        {children}
      </div>
    </>
  );
}
