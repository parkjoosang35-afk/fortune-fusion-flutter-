// [복주머니 마케팅 쿠폰] `/coupon/[token]` 세그먼트 전용 레이아웃.
// `/g/[token]`·`/w/[token]`·`/r/[id]`와 동일하게 바이럴 디자인 톤(Pretendard)을
// 재사용해 카톡 공유 → 이 랜딩(즉시 리다이렉트) → 앱까지 이어지는 톤을
// 통일한다. 루트 layout.tsx(관리자 대시보드 전역)는 손대지 않는다.
export default function BokjuCouponLandingLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <>
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
