import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";

// [신통방통 복주머니 광고 적립 시스템] 시청 내역(조회 전용) 화면.
// operation-logs/page.tsx의 필터+페이지네이션 패턴을 그대로 재사용.
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;

const STATUS_LABELS: Record<string, { label: string; className: string }> = {
  PENDING: { label: "진행중", className: "bg-white text-slate-500" },
  COMPLETED: { label: "지급완료", className: "bg-emerald-100 text-emerald-700" },
  FAILED: { label: "실패", className: "bg-red-100 text-red-700" },
};

interface FortuneAdLogsPageProps {
  searchParams: Promise<{
    page?: string;
    adId?: string;
    rewardStatus?: string;
    userId?: string;
  }>;
}

export default async function FortuneAdLogsPage({ searchParams }: FortuneAdLogsPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const page = Math.max(1, Number(params.page ?? "1") || 1);
  const adId = params.adId ?? "";
  const rewardStatus = params.rewardStatus ?? "";
  const userId = params.userId ?? "";

  const where = {
    ...(adId ? { adId: Number(adId) } : {}),
    ...(rewardStatus ? { rewardStatus } : {}),
    ...(userId ? { userId: Number(userId) } : {}),
  };

  const [total, logs, adOptions] = await Promise.all([
    prisma.fortuneAdWatchLog.count({ where }),
    prisma.fortuneAdWatchLog.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
      include: { user: { select: { nickname: true } }, ad: { select: { title: true } } },
    }),
    prisma.fortuneAd.findMany({
      where: { deletedAt: null },
      orderBy: { id: "asc" },
      select: { id: true, title: true },
    }),
  ]);
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const filterQuery = {
    ...(adId ? { adId } : {}),
    ...(rewardStatus ? { rewardStatus } : {}),
    ...(userId ? { userId } : {}),
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">복주머니 관리 — 광고 시청내역</h1>
        <p className="mt-1 text-sm text-slate-500">
          광고 시청 시작~완료(지급) 이력을 조회합니다(조회 전용). 지급 확정 내역은
          복주머니 원장(PointHistory)에도 sourceType=&quot;AD_WATCH_REWARD&quot;로 함께 기록됩니다.
        </p>
      </div>

      <RewardSubNav />

      <form method="GET" className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-200 bg-white p-4">
        <select
          name="adId"
          defaultValue={adId}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 광고</option>
          {adOptions.map((a) => (
            <option key={a.id} value={a.id}>
              {a.title}
            </option>
          ))}
        </select>
        <select
          name="rewardStatus"
          defaultValue={rewardStatus}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 상태</option>
          <option value="PENDING">진행중</option>
          <option value="COMPLETED">지급완료</option>
          <option value="FAILED">실패</option>
        </select>
        <input
          name="userId"
          defaultValue={userId}
          placeholder="회원 ID 검색"
          className="w-40 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none placeholder:text-slate-500 focus:border-indigo-500"
        />
        <button
          type="submit"
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
        >
          필터 적용
        </button>
      </form>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">시작 시각</th>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">광고</th>
              <th className="px-4 py-3">시청시간</th>
              <th className="px-4 py-3">지급 개수</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">완료 시각</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  조건에 맞는 시청내역이 없습니다.
                </td>
              </tr>
            )}
            {logs.map((log) => {
              const statusInfo = STATUS_LABELS[log.rewardStatus] ?? STATUS_LABELS.PENDING;
              return (
                <tr key={log.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-500">
                    {log.startedAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                  <td className="px-4 py-3 text-slate-700">{log.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-700">{log.ad.title}</td>
                  <td className="px-4 py-3 text-slate-500">
                    {log.watchSeconds != null ? `${log.watchSeconds}s` : "-"}
                  </td>
                  <td className="px-4 py-3 font-medium text-emerald-700">
                    {log.rewardAmount > 0 ? `+${log.rewardAmount}개` : "-"}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs ${statusInfo.className}`}>
                      {statusInfo.label}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">
                    {log.completedAt ? log.completedAt.toISOString().slice(0, 19).replace("T", " ") : "-"}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="mt-4 flex items-center justify-center gap-1">
        {Array.from({ length: totalPages }, (_, i) => i + 1)
          .slice(0, 20)
          .map((p) => (
            <a
              key={p}
              href={`/reward/fortune-ads/logs?${new URLSearchParams({
                ...filterQuery,
                page: String(p),
              }).toString()}`}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                p === page ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-100"
              }`}
            >
              {p}
            </a>
          ))}
      </div>
    </div>
  );
}
