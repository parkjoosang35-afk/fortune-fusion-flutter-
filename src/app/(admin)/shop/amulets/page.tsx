import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AmuletGradeCreateForm from "@/components/AmuletGradeCreateForm";
import AmuletGradeRow from "@/components/AmuletGradeRow";
import AmuletItemCreateForm from "@/components/AmuletItemCreateForm";
import AmuletItemRow from "@/components/AmuletItemRow";

// 05_Admin_System_Design.md §3.4 "상점 관리" — 1차 소단위: 디지털부적 상품 관리
// 04A H-1 amulet_items + H-2 amulet_grades(마스터) CRUD.
// [스코프 결정] user_amulets 등 지급/보유 이력(H-3~H-6)은 회원 활동 결과 데이터이므로
// 이번 1단계 범위에서 제외 — 다음 소단위에서 조회 전용으로 추가할 예정.
export const dynamic = "force-dynamic";

export default async function ShopAmuletsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.write;
  const canDelete = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.delete;

  const [grades, items] = await Promise.all([
    prisma.amuletGrade.findMany({
      where: { deletedAt: null },
      orderBy: { sortOrder: "asc" },
    }),
    prisma.amuletItem.findMany({
      where: { deletedAt: null },
      orderBy: [{ gradeId: "asc" }, { id: "asc" }],
    }),
  ]);

  const itemCountByGrade = new Map<number, number>();
  for (const item of items) {
    itemCountByGrade.set(item.gradeId, (itemCountByGrade.get(item.gradeId) ?? 0) + 1);
  }

  const gradeOptions = grades.map((g) => ({ id: g.id, name: g.name, code: g.code }));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">상점 관리 — 디지털부적</h1>
        <p className="mt-1 text-sm text-slate-400">
          부적 등급 마스터와 부적 상품(종류/등급/효과/이미지/AI생성여부/가격)을 관리합니다.
        </p>
      </div>

      {/* 1) 등급 마스터 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">부적 등급 마스터</h2>
        <AmuletGradeCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">코드</th>
                <th className="px-4 py-3">등급명</th>
                <th className="px-4 py-3">상품 수</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {grades.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 등급이 없습니다.
                  </td>
                </tr>
              )}
              {grades.map((g) => (
                <AmuletGradeRow
                  key={g.id}
                  grade={g}
                  itemCount={itemCountByGrade.get(g.id) ?? 0}
                  canWrite={canWrite}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2) 부적 상품 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">부적 상품 관리</h2>
        <AmuletItemCreateForm canWrite={canWrite} grades={gradeOptions} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">이미지</th>
                <th className="px-4 py-3">이름</th>
                <th className="px-4 py-3">등급</th>
                <th className="px-4 py-3">효과</th>
                <th className="px-4 py-3">가격</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 부적 상품이 없습니다.
                  </td>
                </tr>
              )}
              {items.map((item) => (
                <AmuletItemRow
                  key={item.id}
                  item={item}
                  grades={gradeOptions}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          총 {items.length}종 등록됨. 회원 지급/보유 이력(user_amulets)은 다음 소단위에서
          조회 전용으로 추가될 예정입니다.
        </p>
      </section>
    </div>
  );
}
