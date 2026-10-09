"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// [신통방통 관리자 통합 간소화 실행 지시서 task 8] 6개콘텐츠관리 허브 통합 탭.
//
// 목표 6+1 구조상 사이드바 최상위 메뉴는 "6개콘텐츠관리(ai_content)" 하나만
// 노출하되, 그 아래에서 실제로 운영해야 하는 화면들(AI 프롬프트/카테고리/타로/
// 궁합/소원방/AI로그)을 탭으로 모아 보여준다. RewardSubNav.tsx의 그룹+탭 패턴을
// 그대로 재사용한다.
//
// [RBAC 분리 유지] 소원방(wishroom) 2개 화면은 ai_content와 별도의 RBAC
// 메뉴코드(wishroom)로 가드된다(task 6에서 신설) — community(신고처리함)처럼
// cs 역할도 write 가능해야 하는 등 ai_content와 권한 프로파일이 다르기 때문에
// 권한 체크 자체는 통합하지 않고, "탭으로 모아서 보여주는" 수준의 UI 통합만
// 수행한다(RewardSubNav의 fortune-categories external 탭과 동일한 패턴).
// 귀인지도는 디자인 변경 작업과 충돌을 피하기 위해 이번 허브 통합에서 제외한다
// (신통방통 관리자 통합 간소화 실행 지시서 task 5가 별도로 처리 예정).
interface SubTab {
  href: string;
  label: string;
  /** true면 ai_content가 아닌 다른 RBAC 메뉴코드로 가드되는 화면(외부 묶음) */
  external?: boolean;
}

const TABS: SubTab[] = [
  { href: "/ai-content/prompts", label: "AI 프롬프트 템플릿" },
  { href: "/ai-content/categories", label: "운세 카테고리" },
  { href: "/ai-content/tarot-cards", label: "타로카드 마스터" },
  { href: "/ai-content/tarot-topics", label: "타로 65개 주제" },
  { href: "/ai-content/compatibility-weights", label: "궁합 요소 가중치" },
  { href: "/ai-content/compatibility-stats", label: "궁합 통계" },
  { href: "/wishroom/reports", label: "소원방 신고처리", external: true },
  { href: "/wishroom/reviews", label: "소원방 후기승인", external: true },
  { href: "/ai-content/logs", label: "AI 호출 로그" },
];

export default function AiContentSubNav() {
  const pathname = usePathname();

  return (
    <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
      {TABS.map((tab) => {
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
            {tab.external ? <span className="ml-1 text-xs text-slate-500">↗</span> : null}
          </Link>
        );
      })}
    </nav>
  );
}
