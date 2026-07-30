import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import RankingRewardCreateForm from "@/components/RankingRewardCreateForm";
import RankingRewardRow from "@/components/RankingRewardRow";

// 05_Admin_System_Design.md §3.3 "리워드 관리" — 2차 소단위(랭킹시즌관리, 04A 도메인D 일부)
// 화면 2종을 /reward/ranking 라우트 하위 섹션으로 통합 구현:
//  1) 랭킹 조회(ranking_snapshots, 조회 전용) — 기간(period)별 리더보드
//  2) 랭킹 보상 설정(ranking_rewards) — 순위구간별 보상 CRUD
// ranking_snapshots는 배치로 산출되는 회원 활동 결과이므로 조회 전용으로만 노출한다.
export const dynamic = "force-dynamic";

interface RewardRankingPageProps {
  searchParams: Promise<{ period?: string; rankingType?: string }>;
}

export default async function RewardRankingPage({ searchParams }: RewardRankingPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.write;
  const canDelete = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.delete;

  const params = await searchParams;

  // ── 1) 랭킹 스냅샷 - 조회 가능한 기간/타입 목록 산출 (단순 findMany 후 메모리 집계, 복합인덱스 회피) ──
  const allSnapshots = await prisma.rankingSnapshot.findMany({
    select: { rankingType: true, period: true },
  });
  const periodSet = new Set<string>();
  const typeSet = new Set<string>();
  for (const s of allSnapshots) {
    periodSet.add(s.period);
    typeSet.add(s.rankingType);
  }
  const periods = Array.from(periodSet).sort().reverse();
  const rankingTypes = Array.from(typeSet).sort();

  const selectedPeriod = params.period ?? periods[0] ?? "";
  const selectedType = params.rankingType ?? rankingTypes[0] ?? "point";

  // ── 2) 선택된 기간/타입의 리더보드 조회 (단순 where만 사용) ──
  const leaderboard = selectedPeriod
    ? await prisma.rankingSnapshot.findMany({
        where: { period: selectedPeriod, rankingType: selectedType },
        orderBy: { rank: "asc" },
        take: 50,
        include: { user: { select: { nickname: true } } },
      })
    : [];

  // ── 3) 랭킹 보상 설정 목록 ──
  const rewards = await prisma.rankingReward.findMany({
    where: { deletedAt: null },
    orderBy: [{ rankingType: "asc" }, { rankRangeMin: "asc" }],
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 랭킹</h1>
        <p className="mt-1 text-sm text-slate-400">
          기간별 랭킹 스냅샷을 조회하고, 순위구간별 보상을 설정합니다.
        </p>
      </div>

      <RewardSubNav />

      {/* 1) 랭킹 조회 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">랭킹 조회 (조회 전용)</h2>
        <form
          method="GET"
          className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4"
        >
          <select
            name="rankingType"
            defaultValue={selectedType}
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          >
            {rankingTypes.length === 0 && <option value="point">point</option>}
            {rankingTypes.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
          <select
            name="period"
            defaultValue={selectedPeriod}
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          >
            {periods.length === 0 && <option value="">시즌 데이터 없음</option>}
            {periods.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </select>
          <button
            type="submit"
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
          >
            조회
          </button>
        </form>

        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">순위</th>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">점수</th>
              </tr>
            </thead>
            <tbody>
              {leaderboard.length === 0 && (
                <tr>
                  <td colSpan={3} className="px-4 py-10 text-center text-slate-500">
                    조회 가능한 랭킹 데이터가 없습니다.
                  </td>
                </tr>
              )}
              {leaderboard.map((s) => (
                <tr key={s.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 font-semibold text-slate-200">{s.rank}위</td>
                  <td className="px-4 py-3 text-slate-300">{s.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-400">{s.score.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 랭킹 스냅샷은 배치(스케줄러)가 정기 산출하며, 관리자 화면에서는
          결과만 모니터링합니다.
        </p>
      </section>

      {/* 2) 랭킹 보상 설정 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">랭킹 보상 설정</h2>
        <RankingRewardCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">ranking_type</th>
                <th className="px-4 py-3">순위 구간</th>
                <th className="px-4 py-3">보상</th>
                <th className="px-4 py-3">보상 아이템</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {rewards.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    등록된 랭킹 보상 설정이 없습니다.
                  </td>
                </tr>
              )}
              {rewards.map((r) => (
                <RankingRewardRow key={r.id} reward={r} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
