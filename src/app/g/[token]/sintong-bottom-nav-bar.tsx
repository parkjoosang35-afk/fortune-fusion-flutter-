"use client";

// [2026-09, 웹 하단바 신설 — 사용자 명시 지시 "웹이니까 신통방통 하단바를
// 넣어주고"] 이 초대 랜딩 페이지는 웹(브라우저)에서 열리지만, 실제로는
// `https://sintong.kr/app/`에 배포된 Flutter Web 신통방통 앱과 같은
// 도메인 아래 있다. 화면 맨 아래 신통방통 브랜드 하단 내비게이션 바를
// 고정해, 게스트가 이 랜딩페이지 안에서도 신통방통 앱 전체를 자연스럽게
// 느끼고 다른 탭으로 곧장 넘어갈 수 있게 한다.
//
// [탭 구성] Flutter `lib/core/router/app_shell.dart`의 `_navItems`(5탭:
// 홈/운세/소원방/복주머니/마이)와 동일한 라벨·순서를 사용해 앱과 웹 사이의
// 내비게이션 경험을 통일한다. 각 탭은 앱 설치를 요구하는 커스텀 URI 딥링크가
// 아니라, 이미 배포되어 있는 웹 버전 경로(`SINTONG_WEB_URLS`, hash 라우팅
// `#/경로`)로 직접 이동한다 — 설치 없이 그 자리에서 열린다.
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
    key: "fortune",
    label: "운세",
    href: SINTONG_WEB_URLS.todayFortune,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 3v3M12 18v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M3 12h3M18 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" />
        <circle cx="12" cy="12" r="3.5" />
      </svg>
    ),
  },
  {
    key: "wish-room",
    label: "소원방",
    href: SINTONG_WEB_URLS.wishRoom,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 2c-3.2 3.8-5.4 6.2-5.4 9.2A5.4 5.4 0 0 0 12 16.6a5.4 5.4 0 0 0 5.4-5.4C17.4 8.2 15.2 5.8 12 2z" />
        <path d="M9.5 19.5h5M9 22h6" />
      </svg>
    ),
  },
  {
    key: "guinji",
    label: "귀인지도",
    href: SINTONG_WEB_URLS.guinji,
    icon: (
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <circle cx="12" cy="12" r="2.6" />
        <circle cx="5" cy="6" r="1.6" />
        <circle cx="19" cy="6" r="1.6" />
        <circle cx="5" cy="18" r="1.6" />
        <circle cx="19" cy="18" r="1.6" />
        <path d="M9.8 10.4 6.2 7.2M14.2 10.4l3.6-3.2M9.8 13.6 6.2 16.8M14.2 13.6l3.6 3.2" />
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
      className="fixed inset-x-0 bottom-0 z-40 border-t border-[#ECECEF] bg-white/95 backdrop-blur-sm"
      style={{ paddingBottom: "env(safe-area-inset-bottom, 0px)" }}
      aria-label="신통방통 하단 내비게이션"
    >
      <div className="mx-auto flex h-[60px] w-full max-w-[440px] items-stretch justify-between px-2">
        {NAV_ITEMS.map((item) => (
          <a
            key={item.key}
            href={item.href}
            className="flex flex-1 flex-col items-center justify-center gap-0.5 text-[#9A9AA2] transition hover:text-[#A6795E]"
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
