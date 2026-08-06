"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [메인화면 관리자 편집기] §14 관리자 UI 4개 화면(대시보드/섹션리스트/발행센터/버전히스토리)
// 간 이동을 위한 공용 탭 네비게이션. RewardSubNav.tsx와 동일한 패턴.
const TABS = [
  { href: "/cms/page-configs/home", label: "대시보드" },
  { href: "/cms/page-configs/home/sections", label: "섹션 리스트" },
  { href: "/cms/page-configs/home/publish", label: "미리보기/발행센터" },
  { href: "/cms/page-configs/home/versions", label: "변경로그/버전히스토리" },
];

export default function PageConfigHomeSubNav() {
  const pathname = usePathname();

  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
      {TABS.map((tab) => {
        const active =
          pathname === tab.href ||
          (tab.href !== "/cms/page-configs/home" && pathname.startsWith(tab.href + "/")) ||
          (tab.href === "/cms/page-configs/home" && pathname === "/cms/page-configs/home/");
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`rounded-t-lg px-4 py-2 text-sm font-medium transition ${
              active
                ? "border-b-2 border-indigo-500 text-slate-900"
                : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
