// [궁합지도(Gunghap Map) `/gh/[token]` 랜딩 신설 — Phase 1]
// `/g/[token]`(귀인지도) 세그먼트 전용 레이아웃을 그대로 복제한다. 아이보리+
// 로즈골드 팔레트(--gold:#F5CF6A 등)와 폰트(Noto Serif KR + Pretendard
// Variable)를 이 라우트(`/gh/[token]`) 하위 트리에만 적용해, 카톡 공유 →
// 이 랜딩 → 앱까지 이어지는 바이럴 여정의 디자인 언어를 귀인지도/소원방과
// 통일한다. 루트 `layout.tsx`(관리자 대시보드 전역)는 손대지 않는다 —
// 기존 `/g/[token]/layout.tsx`, `/w/[token]/layout.tsx`도 전혀 수정하지
// 않고 이 파일만 새로 추가한다("기존 귀인지도/소원방 파일 수정 금지" 원칙).
export default function GunghapInviteLayout({
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
