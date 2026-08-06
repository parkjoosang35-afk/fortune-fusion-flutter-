import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import LuckPouchRuleCreateForm from "@/components/LuckPouchRuleCreateForm";
import LuckPouchRuleRow from "@/components/LuckPouchRuleRow";

// [열림패스/행복머니/복주머니 통합정책] §5-3/§9-3/§7 관리자 UI 4. 복주머니 정책 관리.
export const dynamic = "force-dynamic";

export default async function LuckPouchRulesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;
  const canDelete = !!roleMatrix?.delete;

  const rules = await prisma.luckPouchRule.findMany({
    where: { deletedAt: null },
    orderBy: [{ ruleType: "asc" }, { displayPriority: "asc" }, { id: "asc" }],
  });

  const earnCount = rules.filter((r) => r.ruleType === "earn" && r.isActive).length;
  const spendCount = rules.filter((r) => r.ruleType === "spend" && r.isActive).length;
  const purchaseCount = rules.filter((r) => r.ruleType === "purchase" && r.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">리워드 관리 — 복주머니</h1>
        <p className="mt-1 text-sm text-slate-500">
          커뮤니티/참여형 활동 포인트(복주머니)의 적립·소비·구매 규칙을 관리합니다. 복주머니는
          운세 상세 잠금 해제용으로 사용하지 않으며 소원게시판/소원방/부적만들기 등에만 적용됩니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 적립 규칙</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{earnCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 소비 규칙</p>
          <p className="mt-1 text-2xl font-bold text-sky-700">{spendCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 구매 규칙</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{purchaseCount}</p>
        </div>
      </div>

      <LuckPouchRuleCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">규칙명</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">actionType</th>
              <th className="px-4 py-3">scope</th>
              <th className="px-4 py-3">수량</th>
              <th className="px-4 py-3">1일 한도</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {rules.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-slate-500">
                  등록된 복주머니 규칙이 없습니다.
                </td>
              </tr>
            )}
            {rules.map((rule) => (
              <LuckPouchRuleRow key={rule.id} rule={rule} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
