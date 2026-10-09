"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [신통방통 관리자 통합 간소화 실행 지시서 task 6] 소원방 운영 2개 화면 탭 전환.
// RewardSubNav.tsx의 단순 탭 패턴을 그대로 재사용(그룹 없이 2개 평면 탭만 필요).
const TABS = [
  { href: "/wishroom/reports", label: "신고 처리함" },
  { href: "/wishroom/reviews", label: "후기 승인 대기" },
];

export default function WishroomSubNav() {
  const pathname = usePathname();

  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
      {TABS.map((tab) => {
        const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
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
