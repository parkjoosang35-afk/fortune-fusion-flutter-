import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import OpenPassAdSourceCreateForm from "@/components/OpenPassAdSourceCreateForm";
import OpenPassAdSourceRow from "@/components/OpenPassAdSourceRow";

// [사용자 요청: 열림패스 관리자 광고소스 관리] §6-3
export const dynamic = "force-dynamic";

export default async function OpenPassAdSourcesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;
  const canDelete = !!roleMatrix?.delete;

  const [adSources, attachments] = await Promise.all([
    prisma.openPassAdSource.findMany({
      where: { deletedAt: null },
      orderBy: [{ priority: "asc" }, { id: "asc" }],
    }),
    prisma.openPassAttachment.findMany({
      where: { deletedAt: null, isActive: true },
      orderBy: { id: "asc" },
      select: { id: true, fileName: true },
    }),
  ]);

  const bindingCounts = await prisma.openPassProductAdSource.groupBy({
    by: ["adSourceId"],
    where: { isActive: true },
    _count: { _all: true },
  });
  const countMap = new Map(bindingCounts.map((b) => [b.adSourceId, b._count._all]));

  const activeCount = adSources.filter((a) => a.isActive).length;
  const rewardedCount = adSources.filter((a) => a.sourceType.includes("rewarded")).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">리워드 관리 — 프리패스 광고소스</h1>
        <p className="mt-1 text-sm text-slate-500">
          광고 시청 보상으로 프리패스를 지급할 때 사용할 광고 네트워크/유닛을 관리합니다.
          광고소스는 상품과 독립된 재사용 가능 엔티티이며, &quot;상품연결&quot; 화면에서 프리패스 상품에 바인딩합니다.
          <b className="text-amber-700"> [테스트] 라벨</b>이 붙은 mock_rewarded_* 유형은 실제 광고 SDK 없이 항상 같은 결과로 동작하는 테스트 전용 소스입니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">전체 광고소스 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{adSources.length}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 광고소스 수</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activeCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">리워드형 광고소스 수</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{rewardedCount}</p>
        </div>
      </div>

      <OpenPassAdSourceCreateForm canWrite={canWrite} attachmentOptions={attachments} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">광고소스명</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">adUnitId</th>
              <th className="px-4 py-3">쿨다운/일일제한</th>
              <th className="px-4 py-3">우선순위</th>
              <th className="px-4 py-3">fallback</th>
              <th className="px-4 py-3">연결된 상품</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {adSources.length === 0 && (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-slate-500">
                  등록된 광고소스가 없습니다.
                </td>
              </tr>
            )}
            {adSources.map((adSource) => (
              <OpenPassAdSourceRow
                key={adSource.id}
                adSource={adSource}
                linkedProductCount={countMap.get(adSource.id) ?? 0}
                attachmentOptions={attachments}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
