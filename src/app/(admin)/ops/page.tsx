import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [관리자 2.0 전면 재설계 - Task 11] AI시스템관리 — 서버/DB/엔진/API 상태 대시보드.
//
// [배경 — 보고서⑧ 확인 사실] 기존 이 페이지는 UI 없이 역할별로 /admin-users
// 또는 /system-settings로 즉시 리다이렉트만 하는 순수 스텁이었다(실제 상태
// 정보를 전혀 보여주지 않았음). PM2가 100회 재시작했고(원인 미분류), DB
// 백업 자동화와 crontab이 전혀 없다는 사실도 보고서⑧이 확인했다 — 이 화면은
// 그 공백을 메우는 "현재 상태를 한눈에 보는" 조회 전용 대시보드다.
//
// [설계 원칙 — OPERATIONS_POLICY §10] 운영 서버로 실제 헬스체크 HTTP 요청을
// 보내지 않는다(사주엔진 SAJU_ENGINE_BASE_URL 등 포함). 대신 (1) 이미 DB에
// 적재된 ErrorLog/AiRequestLog 등 "이미 수집된" 지표, (2) 서버 프로세스
// 환경변수의 존재 여부만으로 "설정됨" 판정을 한다 — 실제 네트워크 호출 없음.
export const dynamic = "force-dynamic";

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function OpsStatusDashboardPage() {
  const session = await verifyAdminSession();
  const canSeeSecurity = canAccessMenu(session.roleCode, "ops_security");
  const canSeeSystemSettings = canAccessMenu(session.roleCode, "system_settings");
  const canSeeDiagnosis = canAccessMenu(session.roleCode, "ops_system");
  if (!canSeeSecurity && !canSeeSystemSettings && !canSeeDiagnosis) {
    redirect("/dashboard");
  }

  const dayAgo = new Date();
  dayAgo.setDate(dayAgo.getDate() - 1);
  const hourAgo = new Date();
  hourAgo.setHours(hourAgo.getHours() - 1);

  const [
    errorCritical24h,
    errorWarning24h,
    recentErrors,
    aiLogsFailedRecent,
    aiLogsTotalRecent,
    pendingDiagnoses,
    latestLoginLog,
  ] = await Promise.all([
    prisma.errorLog.count({ where: { severity: "critical", createdAt: { gte: dayAgo } } }),
    prisma.errorLog.count({ where: { severity: "warning", createdAt: { gte: dayAgo } } }),
    prisma.errorLog.findMany({ orderBy: { createdAt: "desc" }, take: 5 }),
    prisma.aiRequestLog.count({ where: { status: { not: "success" }, createdAt: { gte: dayAgo } } }),
    prisma.aiRequestLog.count({ where: { createdAt: { gte: dayAgo } } }),
    prisma.systemDiagnosis.count({ where: { status: { in: ["detected", "diagnosed"] } } }),
    prisma.adminLoginLog.findFirst({ orderBy: { createdAt: "desc" } }),
  ]);

  const hasAnthropicKey = !!process.env.ANTHROPIC_APP_API_KEY || !!process.env.ANTHROPIC_API_KEY;
  const hasSajuEngineConfig = !!process.env.SAJU_ENGINE_BASE_URL;
  const dbUrl = process.env.DATABASE_URL ?? "";
  const dbLabel = dbUrl.includes("sqlite") || dbUrl.startsWith("file:") ? "SQLite (파일 기반)" : dbUrl ? "설정됨" : "미설정";

  const serverHealthy = errorCritical24h === 0;
  const aiFailRate = aiLogsTotalRecent > 0 ? (aiLogsFailedRecent / aiLogsTotalRecent) * 100 : 0;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">서버/시스템 상태</h1>
        <p className="mt-1 text-sm text-slate-500">
          DB에 이미 적재된 지표만으로 산출하는 조회 전용 현황판입니다(운영 서버로 실시간 헬스체크 요청은
          보내지 않습니다 — OPERATIONS_POLICY §10).
        </p>
      </div>

      <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">🖥 서버 상태(24h 기준)</p>
          <p className={`mt-2 text-xl font-bold ${serverHealthy ? "text-emerald-700" : "text-rose-700"}`}>
            {serverHealthy ? "정상" : "주의 필요"}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            critical {errorCritical24h}건 · warning {errorWarning24h}건
          </p>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">🗄 데이터베이스</p>
          <p className="mt-2 text-xl font-bold text-slate-900">{dbLabel}</p>
          <p className="mt-1 text-xs text-amber-700">⚠ 자동 백업/crontab 미설정(보고서⑧ 확인) — 수동 백업 권장</p>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">🤖 사주 엔진</p>
          <p className="mt-2 text-xl font-bold text-slate-900">{hasSajuEngineConfig ? "설정됨" : "미설정"}</p>
          <p className="mt-1 text-xs text-slate-500">saju_engine_deploy 저장소 연동 설정 존재 여부</p>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">🔌 AI API 호출(24h)</p>
          <p className="mt-2 text-xl font-bold text-slate-900">
            {aiLogsTotalRecent.toLocaleString()}건
            {aiLogsTotalRecent > 0 && (
              <span className={`ml-2 text-sm font-normal ${aiFailRate > 5 ? "text-rose-700" : "text-slate-500"}`}>
                실패율 {aiFailRate.toFixed(1)}%
              </span>
            )}
          </p>
          <p className="mt-1 text-xs text-slate-500">Anthropic 키: {hasAnthropicKey ? "설정됨" : "미설정"}</p>
        </div>
      </div>

      {canSeeDiagnosis && (
        <section className="mb-8">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-900">🧪 AI 자동진단</h2>
            <Link href="/ai-system/diagnosis" className="text-xs text-indigo-700 hover:underline">
              자동진단 화면으로 이동 →
            </Link>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            {pendingDiagnoses > 0 ? (
              <p className="text-sm text-amber-700">
                ⚠ 처리 대기 중인 진단 건 {pendingDiagnoses}건이 있습니다. 확인이 필요합니다.
              </p>
            ) : (
              <p className="text-sm text-slate-500">현재 처리 대기 중인 자동진단 건이 없습니다.</p>
            )}
          </div>
        </section>
      )}

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">🚨 최근 에러 로그</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">출처</th>
                <th className="px-4 py-3">심각도</th>
                <th className="px-4 py-3">메시지</th>
                <th className="px-4 py-3">발생 시각</th>
              </tr>
            </thead>
            <tbody>
              {recentErrors.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                    에러 로그가 없습니다.
                  </td>
                </tr>
              )}
              {recentErrors.map((e) => (
                <tr key={e.id} className="border-b border-slate-200/60">
                  <td className="px-4 py-3 text-slate-500">{e.source}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs ${
                        e.severity === "critical"
                          ? "bg-rose-100 text-rose-700"
                          : e.severity === "warning"
                            ? "bg-amber-100 text-amber-700"
                            : "bg-slate-100 text-slate-500"
                      }`}
                    >
                      {e.severity}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-700">{e.message}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(e.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <Link href="/system-settings/logs" className="mt-2 inline-block text-xs text-indigo-700 hover:underline">
          전체 로그 보기 →
        </Link>
      </section>

      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {canSeeSecurity && (
          <Link
            href="/admin-users"
            className="rounded-xl border border-slate-200 bg-white p-4 transition hover:border-indigo-300 hover:bg-indigo-100"
          >
            <p className="text-sm font-medium text-slate-800">🔐 관리자 계정/역할(RBAC)</p>
            <p className="mt-1 text-xs text-slate-500">
              마지막 관리자 로그인: {latestLoginLog ? fmtDate(latestLoginLog.createdAt) : "기록 없음"}
            </p>
          </Link>
        )}
        {canSeeSystemSettings && (
          <Link
            href="/system-settings"
            className="rounded-xl border border-slate-200 bg-white p-4 transition hover:border-indigo-300 hover:bg-indigo-100"
          >
            <p className="text-sm font-medium text-slate-800">⚙️ 전역 설정값/에러로그</p>
            <p className="mt-1 text-xs text-slate-500">점검모드, 최소 앱버전 등 전역 설정 관리</p>
          </Link>
        )}
      </section>
    </div>
  );
}
