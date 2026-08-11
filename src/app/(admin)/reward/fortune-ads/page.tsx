import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import { todayRangeKst } from "@/lib/luck-pouch-engine";
import RewardSubNav from "@/components/RewardSubNav";
import FortuneAdCreateForm from "@/components/FortuneAdCreateForm";
import FortuneAdRow from "@/components/FortuneAdRow";

// [신통방통 복주머니 광고 적립 시스템] 관리자 광고 관리 화면.
// open-pass-ad-sources/page.tsx 패턴을 그대로 재사용.
export const dynamic = "force-dynamic";

export default async function FortuneAdsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;
  const canDelete = !!roleMatrix?.delete;

  const ads = await prisma.fortuneAd.findMany({
    where: { deletedAt: null },
    orderBy: [{ priority: "asc" }, { id: "asc" }],
  });

  const { start, end } = todayRangeKst();
  const todayLogs = await prisma.fortuneAdWatchLog.findMany({
    where: {
      adId: { in: ads.map((a) => a.id) },
      rewardStatus: "COMPLETED",
      createdAt: { gte: start, lt: end },
    },
    select: { adId: true, rewardAmount: true },
  });
  const statsMap = new Map<number, { todayCount: number; todayReward: number }>();
  for (const log of todayLogs) {
    const cur = statsMap.get(log.adId) ?? { todayCount: 0, todayReward: 0 };
    cur.todayCount += 1;
    cur.todayReward += log.rewardAmount;
    statsMap.set(log.adId, cur);
  }

  const activeCount = ads.filter((a) => a.isActive).length;
  const totalRewardToday = todayLogs.reduce((sum, l) => sum + l.rewardAmount, 0);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">복주머니 관리 — 광고관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          광고 시청 완료 시 서버 검증을 거쳐 복주머니(Wallet POINT)를 자동 지급합니다.
          여기서 등록/설정한 내용은 재배포 없이 앱에 즉시 반영됩니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">전체 광고 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{ads.length}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">노출중 광고 수</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activeCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">오늘 지급된 복주머니</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{totalRewardToday}개</p>
        </div>
      </div>

      <FortuneAdCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">광고명</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">보상/시청시간</th>
              <th className="px-4 py-3">일일제한</th>
              <th className="px-4 py-3">오늘 시청/지급</th>
              <th className="px-4 py-3">우선순위</th>
              <th className="px-4 py-3">노출</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {ads.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-slate-500">
                  등록된 광고가 없습니다.
                </td>
              </tr>
            )}
            {ads.map((ad) => (
              <FortuneAdRow
                key={ad.id}
                ad={ad}
                todayStats={statsMap.get(ad.id) ?? { todayCount: 0, todayReward: 0 }}
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
