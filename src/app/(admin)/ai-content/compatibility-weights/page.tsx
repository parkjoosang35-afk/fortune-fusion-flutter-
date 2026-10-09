import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import CompatibilityWeightTable from "@/components/CompatibilityWeightTable";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 5차 소단위(도메인 F 1단계): 궁합 요소 가중치 설정
// 04A F-3 compatibility_factor_weights 조회 + 정책 수치(weight) 조정 +
// 활성/비활성 토글. §3.6 6개 화면 중 유일하게 write(Server Action)가 필요한
// 화면이다(actions/compatibility-weights.ts 참조).
// [factor_type 고정 5종] 04A 명시 화이트리스트(saju/mbti/interest/value/
//   activity_pattern)로 이미 UQ 제약이 걸려 있어, 신규 생성/삭제 UI는
//   제공하지 않는다(초기 시딩으로 5건 고정, 수치 조정과 활성토글만 관리자
//   가능 — actions 파일의 범위 결정 참조).
//
// [신통방통 관리자 통합 간소화 실행 지시서 task 7] matching(매칭/궁합 관리)은
// 매칭 기능 자체가 앱에서 완전히 제거되어 사이드바에서 off 처리되었지만,
// "궁합"은 Flutter에 실사용 화면(features/compatibility)이 있어 삭제 대상이
// 아니다(rbac.ts ADMIN_MENU_GROUPS 주석 참조). 이 화면을 matching 디렉터리에서
// ai-content(6개콘텐츠관리) 아래로 옮겨 "매칭 삭제, 궁합은 콘텐츠로 유지"
// 원칙을 실제 라우트 구조에 반영한다(가드도 matching→ai_content로 전환).
export const dynamic = "force-dynamic";

const FACTOR_LABEL: Record<string, string> = {
  saju: "사주",
  mbti: "MBTI",
  interest: "취미/관심사",
  value: "가치관",
  activity_pattern: "활동패턴",
};

export default async function CompatibilityWeightsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "ai_content");

  const items = await prisma.compatibilityFactorWeight.findMany({
    where: { deletedAt: null },
    orderBy: { weight: "desc" },
  });

  const activeSum = items.filter((i) => i.isActive).reduce((s, i) => s + i.weight, 0);
  const sumWarning = Math.abs(activeSum - 1.0) > 0.01;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">6개콘텐츠관리 — 궁합 요소 가중치 설정</h1>
        <p className="mt-1 text-sm text-slate-500">
          AI 궁합 계산에 사용되는 사주/MBTI/취미/가치관/활동패턴 요소별 가중치를 조정합니다.
          활성 요소의 가중치 합계는 1.00을 권장합니다(04A F-3 명시, 강제 아님).
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/ai-content/prompts" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            프롬프트 템플릿
          </Link>
          <Link href="/ai-content/categories" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            운세 카테고리
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">궁합 요소 가중치</span>
          <Link href="/ai-content/compatibility-stats" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            궁합 통계
          </Link>
        </nav>
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-4 text-sm text-slate-500">
        <span>
          전체 요소 <span className="text-slate-900">{items.length}</span>개
        </span>
        <span>
          활성 요소 가중치 합계{" "}
          <span className={sumWarning ? "text-amber-700" : "text-emerald-700"}>{activeSum.toFixed(2)}</span>
          {sumWarning && <span className="ml-1 text-amber-700">(권장값 1.00에서 벗어남)</span>}
        </span>
      </div>

      <CompatibilityWeightTable
        items={items.map((i) => ({
          id: i.id,
          factorType: i.factorType,
          weight: i.weight,
          isActive: i.isActive,
          updatedAt: i.updatedAt,
        }))}
        canWrite={canWrite}
      />
      <p className="mt-2 text-xs text-slate-500">
        04A F-3 명시: factor_type은 UQ 제약(saju/mbti/interest/value/activity_pattern 5종
        고정), weight는 DECIMAL(3,2)(합 1.00 권장, 애플리케이션 검증)입니다. 요소:{" "}
        {Object.entries(FACTOR_LABEL)
          .map(([k, v]) => `${v}(${k})`)
          .join(", ")}
      </p>
    </div>
  );
}
