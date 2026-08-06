import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import AttendanceRuleCreateForm from "@/components/AttendanceRuleCreateForm";
import AttendanceRuleRow from "@/components/AttendanceRuleRow";
import MissionCreateForm from "@/components/MissionCreateForm";
import MissionRow from "@/components/MissionRow";

// 05_Admin_System_Design.md §3.3 "리워드 관리" — 2차 소단위(출석/미션, 04A 도메인D 일부)
// 화면 2종을 /reward/missions 라우트 하위 섹션으로 통합 구현:
//  1) 출석보상규칙설정(attendance_reward_rules) — 마스터 CRUD
//  2) 미션관리(missions) — 마스터 CRUD + 회원 진행현황(user_missions, 조회 전용) 요약
// attendances/user_missions는 회원 활동 결과 데이터이므로 조회 전용으로만 노출한다.
export const dynamic = "force-dynamic";

export default async function RewardMissionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.write;
  const canDelete = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.delete;

  // ── 1) 출석보상규칙 목록 ──
  const rules = await prisma.attendanceRewardRule.findMany({
    where: { deletedAt: null },
    orderBy: { streakDay: "asc" },
  });

  // ── 2) 미션 목록 ──
  const missions = await prisma.mission.findMany({
    where: { deletedAt: null },
    orderBy: [{ periodType: "asc" }, { id: "asc" }],
  });

  // ── 3) 회원 미션 진행현황 요약 (조회 전용, 최근 50건) ──
  const userMissions = await prisma.userMission.findMany({
    orderBy: { updatedAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true } },
      mission: { select: { title: true, targetCount: true } },
    },
  });

  // ── 4) 최근 30일 출석 통계 요약 (조회 전용) ──
  const attendanceCount = await prisma.attendance.count();
  const attendanceStreakTop = await prisma.attendance.findMany({
    orderBy: { streakCount: "desc" },
    take: 5,
    include: { user: { select: { nickname: true } } },
  });

  const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
    in_progress: { label: "진행중", cls: "bg-white text-slate-500" },
    completed: { label: "완료", cls: "bg-amber-100 text-amber-700" },
    claimed: { label: "지급완료", cls: "bg-emerald-100 text-emerald-700" },
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">리워드 관리 — 출석/미션</h1>
        <p className="mt-1 text-sm text-slate-500">
          출석보상규칙 및 미션 마스터를 관리하고, 회원의 출석/미션 진행현황을 조회합니다.
        </p>
      </div>

      <RewardSubNav />

      {/* 1) 출석보상규칙설정 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">출석보상규칙설정</h2>
        <AttendanceRuleCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">연속 출석일</th>
                <th className="px-4 py-3">보상 포인트</th>
                <th className="px-4 py-3">보너스 유형</th>
                <th className="px-4 py-3">보너스 ID</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {rules.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    등록된 규칙이 없습니다.
                  </td>
                </tr>
              )}
              {rules.map((r) => (
                <AttendanceRuleRow key={r.id} rule={r} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          총 누적 출석 기록: {attendanceCount.toLocaleString()}건 (조회 전용, 최근 30일 기준 시딩됨)
          {attendanceStreakTop.length > 0 && (
            <>
              {" · "}최고 연속출석:{" "}
              {attendanceStreakTop
                .map((a) => `${a.user.nickname}(${a.streakCount}일)`)
                .join(", ")}
            </>
          )}
        </p>
      </section>

      {/* 2) 미션관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">미션관리</h2>
        <MissionCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">action_type</th>
                <th className="px-4 py-3">주기</th>
                <th className="px-4 py-3">목표</th>
                <th className="px-4 py-3">보상</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {missions.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 미션이 없습니다.
                  </td>
                </tr>
              )}
              {missions.map((m) => (
                <MissionRow key={m.id} mission={m} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 3) 회원 미션 진행현황 (조회 전용) */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">회원 미션 진행현황 (조회 전용, 최근 50건)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">미션</th>
                <th className="px-4 py-3">진행도</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">지급 시각</th>
              </tr>
            </thead>
            <tbody>
              {userMissions.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    진행중인 미션이 없습니다.
                  </td>
                </tr>
              )}
              {userMissions.map((um) => {
                const st = STATUS_LABEL[um.status] ?? { label: um.status, cls: "bg-white text-slate-500" };
                return (
                  <tr key={um.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                    <td className="px-4 py-3 text-slate-700">{um.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-600">{um.mission.title}</td>
                    <td className="px-4 py-3 text-slate-500">
                      {um.progressCount}/{um.mission.targetCount}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-500">
                      {um.claimedAt ? um.claimedAt.toISOString().slice(0, 19).replace("T", " ") : "-"}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 회원의 미션 진행/완료/보상수령 처리는 앱(회원측) 활동에서
          발생하며, 관리자 화면에서는 결과만 모니터링합니다.
        </p>
      </section>
    </div>
  );
}
