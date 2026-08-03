import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import HappyMoneyProductCreateForm from "@/components/HappyMoneyProductCreateForm";
import HappyMoneyProductRow from "@/components/HappyMoneyProductRow";

// [열림패스/행복머니/복주머니 통합정책] §5-2/§9-2/§7 관리자 UI 3. 행복머니 정책 관리.
// pass-policies/page.tsx와 동일한 Server Component 페이지 템플릿을 그대로 따른다.
export const dynamic = "force-dynamic";

export default async function HappyMoneyProductsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;
  const canDelete = !!roleMatrix?.delete;

  const products = await prisma.happyMoneyProduct.findMany({
    where: { deletedAt: null },
    orderBy: [{ displayPriority: "asc" }, { id: "asc" }],
  });

  const activeCount = products.filter((p) => p.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 행복머니</h1>
        <p className="mt-1 text-sm text-slate-400">
          유료 충전 포인트(행복머니) 상품을 관리합니다. 행복머니는 열림패스 구매, 구독, 상품권 등
          유료 구매 전용 자산이며 커뮤니티 소액 반응 재화로는 사용하지 않습니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">전체 상품 수</p>
          <p className="mt-1 text-2xl font-bold text-white">{products.length}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">활성 상품 수</p>
          <p className="mt-1 text-2xl font-bold text-emerald-400">{activeCount}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">추천 상품 수</p>
          <p className="mt-1 text-2xl font-bold text-amber-400">{products.filter((p) => p.isFeatured).length}</p>
        </div>
      </div>

      <HappyMoneyProductCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 bg-slate-900 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">상품명</th>
              <th className="px-4 py-3">현금 가격</th>
              <th className="px-4 py-3">지급 행복머니</th>
              <th className="px-4 py-3">사용 가능 상품군</th>
              <th className="px-4 py-3">우선순위</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {products.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                  등록된 행복머니 상품이 없습니다.
                </td>
              </tr>
            )}
            {products.map((product) => (
              <HappyMoneyProductRow key={product.id} product={product} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
