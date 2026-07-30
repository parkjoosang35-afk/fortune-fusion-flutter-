"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [신규] 리워드 관리(§3.3) 하위 5개 화면(정책/미션·출석/업적/랭킹/알림패스) 간
// 이동을 위한 공용 탭 네비게이션. 사이드바는 /reward/policies 하나만 진입점으로
// 가리키므로(rbac.ts ADMIN_MENU_GROUPS), 하위 화면 간 이동 수단이 없던 기존
// 문제(missions/achievements/ranking도 URL 직접 입력으로만 접근 가능)를
// 알림패스 화면 신설과 함께 개선한다. 문서1(§유지/보류/제거) "알림패스 관리자
// UI 부재" 항목의 부수 효과로, 기존 4개 화면에도 동일 컴포넌트를 추가한다.
const TABS = [
  { href: "/reward/policies", label: "포인트/경제" },
  { href: "/reward/missions", label: "출석/미션" },
  { href: "/reward/achievements", label: "업적" },
  { href: "/reward/ranking", label: "랭킹" },
  { href: "/reward/pass-policies", label: "알림패스" },
];

export default function RewardSubNav() {
  const pathname = usePathname();

  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-800">
      {TABS.map((tab) => {
        const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`rounded-t-lg px-4 py-2 text-sm font-medium transition ${
              active
                ? "border-b-2 border-indigo-500 text-white"
                : "text-slate-400 hover:text-slate-200"
            }`}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
