"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [신통방통 관리자 통합 간소화 실행 지시서 task 10 "운영/보안+시스템설정 최소
// 메뉴로 통합"] 기존에는 "운영/보안"(ops_security, super_admin 전용)과
// "시스템 설정"(system_settings, super_admin+operator 열람 가능)이 사이드바
// 최상위에 별도 메뉴로 분리되어 있었다(각 메뉴 내부는 이미 자체 nav로
// 4개/3개 화면이 통합되어 있었음 — admin-users/page.tsx, system-settings/
// page.tsx의 기존 <nav> 블록 참고). 지시서의 "운영보안+시스템오류확인은
// 별도 최소 운영메뉴로 유지"에 맞춰 두 메뉴를 사이드바 1개 항목
// ("운영·시스템관리")으로 합치되, RBAC_MATRIX/canAccessMenu 등 실제 권한
// 판정 로직은 전혀 건드리지 않는다(회귀 위험 최소화 — ops_security는
// 여전히 super_admin만 read 가능, system_settings는 super_admin+operator
// read 가능이라는 기존 권한 그대로 유지, 가드는 각 page.tsx가 그대로 담당).
// 이 컴포넌트는 7개 화면 전체를 하나의 탭으로 보여주되, canAccessOpsSecurity/
// canAccessSystemSettings를 받아 역할에 안 보이는 탭은 아예 렌더링하지 않는다
// (예: operator 역할은 ops_security 4개 탭이 보이지 않고 system_settings
// 3개 탭만 보임 — 클릭해도 어차피 각 page.tsx가 redirect하므로 이중 안전).
interface SubTab {
  href: string;
  label: string;
  group: "ops_security" | "system_settings";
}

const TABS: SubTab[] = [
  { href: "/admin-users", label: "관리자 계정 관리", group: "ops_security" },
  { href: "/admin-users/roles", label: "역할/권한 매트릭스", group: "ops_security" },
  { href: "/admin-users/login-logs", label: "관리자 로그인 이력", group: "ops_security" },
  { href: "/audit-logs", label: "감사로그(Audit) 조회", group: "ops_security" },
  { href: "/system-settings", label: "전역 설정값 관리", group: "system_settings" },
  { href: "/system-settings/logs", label: "접근/에러 로그 조회", group: "system_settings" },
  { href: "/system-settings/statistics", label: "통계 스냅샷 관리", group: "system_settings" },
];

interface OpsSystemSubNavProps {
  canAccessOpsSecurity: boolean;
  canAccessSystemSettings: boolean;
}

export default function OpsSystemSubNav({
  canAccessOpsSecurity,
  canAccessSystemSettings,
}: OpsSystemSubNavProps) {
  const pathname = usePathname();
  const visibleTabs = TABS.filter((tab) =>
    tab.group === "ops_security" ? canAccessOpsSecurity : canAccessSystemSettings
  );

  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
      {visibleTabs.map((tab) => {
        const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`rounded-t-lg px-3 py-2 text-sm font-medium transition ${
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
