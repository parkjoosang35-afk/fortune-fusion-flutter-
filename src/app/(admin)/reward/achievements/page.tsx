import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AchievementCreateForm from "@/components/AchievementCreateForm";
import AchievementRow from "@/components/AchievementRow";

// 05_Admin_System_Design.md §3.3 "리워드 관리" — 2차 소단위(업적, 04A 도메인D 일부)
// 화면 1종을 /reward/achievements 라우트로 구현:
//  1) 업적관리(achievements) — 마스터 CRUD
//  2) 회원 업적 달성현황(user_achievements, 조회 전용) 요약
// user_achievements는 회원 활동 결과 데이터이므로 조회 전용으로만 노출한다.
export const dynamic = "force-dynamic";

export default async function RewardAchievementsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.write;
  const canDelete = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.delete;

  // ── 1) 업적 목록 ──
  const achievements = await prisma.achievement.findMany({
    where: { deletedAt: null },
    orderBy: { id: "asc" },
  });

  // ── 2) 회원 업적 달성현황 (조회 전용, 최근 50건) ──
  const userAchievements = await prisma.userAchievement.findMany({
    orderBy: { achievedAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true } },
      achievement: { select: { title: true, code: true } },
    },
  });

  // ── 3) 업적별 달성자 수 요약 (조회 전용, 메모리 집계로 복합인덱스 회피) ──
  const allUserAchievements = await prisma.userAchievement.findMany({
    select: { achievementId: true },
  });
  const achievedCountMap = new Map<number, number>();
  for (const ua of allUserAchievements) {
    achievedCountMap.set(ua.achievementId, (achievedCountMap.get(ua.achievementId) ?? 0) + 1);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 업적</h1>
        <p className="mt-1 text-sm text-slate-400">
          업적 마스터를 관리하고, 회원의 업적 달성현황을 조회합니다.
        </p>
      </div>

      {/* 1) 업적관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">업적관리</h2>
        <AchievementCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">code</th>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">condition_type</th>
                <th className="px-4 py-3">condition_value</th>
                <th className="px-4 py-3">보상</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {achievements.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 업적이 없습니다.
                  </td>
                </tr>
              )}
              {achievements.map((a) => (
                <AchievementRow key={a.id} achievement={a} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
        {achievements.length > 0 && (
          <p className="mt-2 text-xs text-slate-500">
            업적별 달성자 수:{" "}
            {achievements
              .map((a) => `${a.title}(${achievedCountMap.get(a.id) ?? 0}명)`)
              .join(", ")}
          </p>
        )}
      </section>

      {/* 2) 회원 업적 달성현황 (조회 전용) */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">회원 업적 달성현황 (조회 전용, 최근 50건)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">업적</th>
                <th className="px-4 py-3">code</th>
                <th className="px-4 py-3">달성 시각</th>
              </tr>
            </thead>
            <tbody>
              {userAchievements.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    달성된 업적이 없습니다.
                  </td>
                </tr>
              )}
              {userAchievements.map((ua) => (
                <tr key={ua.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{ua.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-300">{ua.achievement.title}</td>
                  <td className="px-4 py-3 font-mono text-slate-500">{ua.achievement.code}</td>
                  <td className="px-4 py-3 text-slate-500">
                    {ua.achievedAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 회원의 업적 달성 판정 및 보상수령 처리는 앱(회원측)
          활동에서 발생하며, 관리자 화면에서는 결과만 모니터링합니다.
        </p>
      </section>
    </div>
  );
}
