"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [재화 구조 정리 - 관리자 축소] 리워드 관리 하위 화면을 "최종 5-메뉴 최소 관리자"
// 구조로 재편한다. 최상위 사이드바(회원/커뮤니티/결제/CMS 등 다른 11개 메뉴)는
// 이번 작업 범위가 아니므로 그대로 두고, /reward/* 안에서만 아래 5개 그룹으로
// 통합한다(기존 화면 파일은 삭제하지 않고 그대로 재사용 — 값만 다루는 화면들을
// 그룹으로 묶어 노출 경로만 정리).
//   1) 프리패스관리   - 열림패스 정책 + 첨부파일 + 광고소스 + 상품연결
//   2) 복주머니관리   - 복주머니 규칙 + 포인트/경제(일일상한) + 출석/미션 + 업적 +
//                       랭킹 보상 + 기능-자산 매핑 (전부 "복주머니를 얼마나
//                       주고받는지" 값을 설정하는 화면이라 하나로 묶는다)
//   3) 운세카테고리관리 - 기존 AI콘텐츠관리 하위 카테고리 화면을 재사용(외부 링크)
//   4) 테스트랩       - 기존 그대로
//   5) 운영로그/내역확인 - 신규: 복주머니 적립/사용 내역(PointHistory) 조회 전용
// [금지] 행복머니(happy-money-products)는 최종 2-자산 구조(프리패스+복주머니)
// 확정에 따라 내비게이션에서 완전히 제거한다(데이터/라우트 파일은 보존, 링크만 삭제).
interface SubTab {
  href: string;
  label: string;
}

interface NavGroup {
  key: string;
  label: string;
  href: string;
  /** 그룹에 속한 하위 경로들(활성 판정 + 2단계 탭 렌더링용). 없으면 href 하나만 사용. */
  matchPrefixes?: string[];
  children?: SubTab[];
  /** true면 /reward 밖의 다른 최상위 메뉴로 나가는 단순 링크(2단계 탭 없음). */
  external?: boolean;
}

const GROUPS: NavGroup[] = [
  {
    // [프리패스 단순화 - 쿠팡파트너스 전용] §1/§10 — 프리패스는 이제
    // 쿠팡 파트너스 광고 전용 기능으로만 운영되어 이용시간/대기시간 설정 +
    // CMS 쿠팡파트너스 배너 등록이 pass-policies 화면 하나로 통합되었다.
    // 기존 첨부파일/광고소스/상품연결 3개 하위 화면(라우트 파일은 보존)은
    // 더 이상 정상 운영 흐름에서 쓰이지 않으므로 내비게이션에서만 제거한다.
    key: "pass",
    label: "프리패스관리",
    href: "/reward/pass-policies",
    matchPrefixes: ["/reward/pass-policies"],
  },
  {
    key: "luckpouch",
    label: "복주머니관리",
    href: "/reward/luck-pouch-rules",
    matchPrefixes: [
      "/reward/luck-pouch-rules",
      "/reward/policies",
      "/reward/missions",
      "/reward/achievements",
      "/reward/ranking",
      "/reward/feature-bindings",
      "/reward/fortune-ads",
    ],
    children: [
      { href: "/reward/luck-pouch-rules", label: "적립/사용 규칙" },
      { href: "/reward/policies", label: "경제 정책(일일상한)" },
      { href: "/reward/missions", label: "출석/미션" },
      { href: "/reward/achievements", label: "업적" },
      { href: "/reward/ranking", label: "랭킹 보상" },
      { href: "/reward/feature-bindings", label: "기능-자산 매핑" },
      // [복주머니 광고 적립 시스템 - 2026-08] 광고 시청→복주머니 지급 관리 화면.
      { href: "/reward/fortune-ads", label: "광고관리" },
      { href: "/reward/fortune-ads/logs", label: "시청내역" },
    ],
  },
  {
    key: "fortune-categories",
    label: "운세카테고리관리",
    href: "/ai-content/categories",
    external: true,
  },
  {
    key: "test-lab",
    label: "테스트랩",
    href: "/reward/test-lab",
  },
  {
    key: "logs",
    label: "운영로그/내역확인",
    href: "/reward/operation-logs",
  },
];

function isGroupActive(group: NavGroup, pathname: string): boolean {
  const prefixes = group.matchPrefixes ?? [group.href];
  return prefixes.some((p) => pathname === p || pathname.startsWith(p + "/"));
}

export default function RewardSubNav() {
  const pathname = usePathname();
  const activeGroup = GROUPS.find((g) => !g.external && isGroupActive(g, pathname));

  return (
    <div className="mb-6">
      <nav className="flex flex-wrap gap-1 border-b border-slate-200">
        {GROUPS.map((group) => {
          const active = group.external
            ? pathname.startsWith(group.href)
            : isGroupActive(group, pathname);
          return (
            <Link
              key={group.key}
              href={group.href}
              className={`rounded-t-lg px-4 py-2 text-sm font-medium transition ${
                active
                  ? "border-b-2 border-indigo-500 text-slate-900"
                  : "text-slate-500 hover:text-slate-700"
              }`}
            >
              {group.label}
              {group.external ? (
                <span className="ml-1 text-xs text-slate-500">↗</span>
              ) : null}
            </Link>
          );
        })}
      </nav>

      {/* [관리자 축소] 그룹 내부 2단계 탭 - 프리패스관리/복주머니관리처럼 여러
          화면을 하나로 묶은 그룹만 표시한다(테스트랩/운영로그는 단일 화면). */}
      {activeGroup?.children ? (
        <nav className="mt-2 flex flex-wrap gap-1">
          {activeGroup.children.map((tab) => {
            const active = pathname === tab.href || pathname.startsWith(tab.href + "/");
            return (
              <Link
                key={tab.href}
                href={tab.href}
                className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                  active
                    ? "bg-indigo-600 text-white"
                    : "bg-white text-slate-500 hover:bg-slate-100 hover:text-slate-700"
                }`}
              >
                {tab.label}
              </Link>
            );
          })}
        </nav>
      ) : null}
    </div>
  );
}
