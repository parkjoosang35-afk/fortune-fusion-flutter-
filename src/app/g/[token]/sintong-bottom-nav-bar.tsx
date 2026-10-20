"use client";

// [2026-09, 웹 하단바 신설 — 사용자 명시 지시 "웹이니까 신통방통 하단바를
// 넣어주고"] 이 초대 랜딩 페이지는 웹(브라우저)에서 열리지만, 실제로는
// `https://sintong.kr/app/`에 배포된 Flutter Web 신통방통 앱과 같은
// 도메인 아래 있다. 화면 맨 아래 신통방통 브랜드 하단 내비게이션 바를
// 고정해, 게스트가 이 랜딩페이지 안에서도 신통방통 앱 전체를 자연스럽게
// 느끼고 다른 탭으로 곧장 넘어갈 수 있게 한다.
//
// [2026-11, "웹 UI 간편 통일 지시서" — 하단바 4탭 동기화] 앱 쪽
// 하단바는 여러 차례 리팩터링을 거쳐 현재 `lib/core/widgets/
// midnight_bottom_nav.dart`의 `kMidnightNavTabs`(4탭: 홈/신당부적/
// 복주머니/마이) 구조로 바뀌었다. 과거 5탭(홈/운세/소원방/귀인지도/마이)
// 구성은 더 이상 앱과 일치하지 않으므로, 이 공용 웹 하단바도 동일한
// 4탭·동일한 다크 팔레트(`MidnightNavTokens`: 배경 #0E0A14, 비활성
// 텍스트 반투명 아이보리, 활성/호버 골드 #F5CF6A)로 맞춘다. Flutter를
// 직접 수정하지 않는다는 원칙에 따라 색상 값만 상수로 옮겨와 참고한다.
// 소원방/귀인지도는 하단바 라벨에서는 빠졌지만 서비스 자체는 유지되므로
// (앱에서도 홈 카드 등 다른 진입점으로 계속 접근 가능) 여기서는 삭제하지
// 않고 그대로 두되, 탭 자체는 앱 기준 4탭으로 교체한다.
import { SINTONG_WEB_URLS } from "./sintong-web-urls";

const NAV_ITEMS: { key: string; label: string; href: string; icon: React.ReactNode }[] = [
  {
    key: "home",
    label: "홈",
    href: SINTONG_WEB_URLS.home,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M3 11.5 12 4l9 7.5" />
        <path d="M5.5 10v9.5a1 1 0 0 0 1 1H9.5v-6h5v6H17.5a1 1 0 0 0 1-1V10" />
      </svg>
    ),
  },
  {
    key: "shrine",
    label: "신당부적",
    href: SINTONG_WEB_URLS.shrine,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 2.5c-2.6 2.6-3.6 4.4-3.6 6.4a3.6 3.6 0 0 0 7.2 0c0-2-1-3.8-3.6-6.4z" />
        <path d="M6.5 13.5h11l1 7.5h-13z" />
        <path d="M9.3 13.5v7.5M14.7 13.5v7.5" />
      </svg>
    ),
  },
  {
    key: "pouch",
    label: "복주머니",
    href: SINTONG_WEB_URLS.pouch,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M8.5 8.5c0-2.2 1.6-4 3.5-4s3.5 1.8 3.5 4" />
        <path d="M5.8 8.5h12.4l1.3 9.2a2.4 2.4 0 0 1-2.4 2.8H6.9a2.4 2.4 0 0 1-2.4-2.8z" />
        <circle cx="12" cy="13" r="1.6" />
      </svg>
    ),
  },
  {
    key: "my",
    label: "마이",
    href: SINTONG_WEB_URLS.home,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <circle cx="12" cy="8.2" r="3.2" />
        <path d="M5 20c0-3.6 3.1-6.2 7-6.2s7 2.6 7 6.2" />
      </svg>
    ),
  },
];

export function SintongBottomNavBar() {
  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 border-t border-[#1EFFEBC8]/10 bg-[#0E0A14]/95 backdrop-blur-sm"
      style={{ paddingBottom: "env(safe-area-inset-bottom, 0px)" }}
      aria-label="신통방통 하단 내비게이션"
    >
      <div className="mx-auto flex h-[60px] w-full max-w-[440px] items-stretch justify-between px-2">
        {NAV_ITEMS.map((item) => (
          <a
            key={item.key}
            href={item.href}
            className="flex flex-1 flex-col items-center justify-center gap-0.5 text-[#E8DCC8]/50 transition hover:text-[#F5CF6A]"
          >
            {item.icon}
            <span
              className="text-[11px] font-semibold"
              style={{ letterSpacing: "-0.2px" }}
            >
              {item.label}
            </span>
          </a>
        ))}
      </div>
    </nav>
  );
}
