import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

// 05_Admin_System_Design.md §3.11 "시스템 설정" — 2차 소단위: "접근/에러 로그 조회"
// (04A O-3 access_logs, O-4 error_logs — Append-only, 조회 전용, critical 필터)
// admin-users/login-logs, audit-logs에서 확립된 조회 전용 화면 패턴을 재사용한다.
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;

const SEVERITY_LABEL: Record<string, string> = {
  info: "정보",
  warning: "경고",
  critical: "긴급",
};

const SOURCE_LABEL: Record<string, string> = {
  api: "API",
  batch: "배치",
  ai: "AI",
};

export default async function SystemLogsPage({
  searchParams,
}: {
  searchParams: Promise<{
    tab?: string;
    status?: string;
    severity?: string;
    source?: string;
    page?: string;
  }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "system_settings")) {
    redirect("/dashboard");
  }

  const sp = await searchParams;
  const tab = sp.tab === "error" ? "error" : "access"; // 기본 탭: access_logs
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);

  function formatDate(d: Date): string {
    return d.toISOString().slice(0, 19).replace("T", " ");
  }

  function buildQuery(overrides: Record<string, string | undefined>) {
    const params = new URLSearchParams();
    const merged = {
      tab: sp.tab,
      status: sp.status,
      severity: sp.severity,
      source: sp.source,
      page: sp.page,
      ...overrides,
    };
    Object.entries(merged).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    return `/system-settings/logs?${params.toString()}`;
  }

  // ── access_logs 탭 ──
  let accessLogs: Awaited<ReturnType<typeof prisma.accessLog.findMany>> = [];
  let accessTotal = 0;
  if (tab === "access") {
    const statusFilter = sp.status ? parseInt(sp.status, 10) : undefined;
    const where = statusFilter ? { responseStatus: statusFilter } : {};
    [accessLogs, accessTotal] = await Promise.all([
      prisma.accessLog.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
      prisma.accessLog.count({ where }),
    ]);
  }

  // ── error_logs 탭 ──
  let errorLogs: Awaited<ReturnType<typeof prisma.errorLog.findMany>> = [];
  let errorTotal = 0;
  if (tab === "error") {
    const where: { severity?: string; source?: string } = {};
    if (sp.severity) where.severity = sp.severity;
    if (sp.source) where.source = sp.source;
    [errorLogs, errorTotal] = await Promise.all([
      prisma.errorLog.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
      prisma.errorLog.count({ where }),
    ]);
  }

  const total = tab === "access" ? accessTotal : errorTotal;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">시스템 설정 — 접근/에러 로그 조회</h1>
        <p className="mt-1 text-sm text-slate-400">
          서버 접근 로그(access_logs)와 시스템 에러 로그(error_logs)를 조회합니다. critical
          등급 에러는 운영팀 알림 연계 대상입니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/system-settings" className="px-3 py-2 text-slate-400 hover:text-white">
            전역 설정값 관리
          </Link>
          <Link
            href="/system-settings/logs"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            접근/에러 로그 조회
          </Link>
          <Link
            href="/system-settings/statistics"
            className="px-3 py-2 text-slate-400 hover:text-white"
          >
            통계 스냅샷 관리
          </Link>
        </nav>
      </div>

      <div className="mb-4 flex gap-2 text-sm">
        <Link
          href="/system-settings/logs?tab=access"
          className={`rounded-lg px-4 py-2 ${
            tab === "access"
              ? "bg-indigo-600 text-white"
              : "bg-slate-800 text-slate-400 hover:bg-slate-700"
          }`}
        >
          접근 로그(access_logs)
        </Link>
        <Link
          href="/system-settings/logs?tab=error"
          className={`rounded-lg px-4 py-2 ${
            tab === "error"
              ? "bg-indigo-600 text-white"
              : "bg-slate-800 text-slate-400 hover:bg-slate-700"
          }`}
        >
          에러 로그(error_logs)
        </Link>
      </div>

      {tab === "access" ? (
        <>
          <form className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
            <input type="hidden" name="tab" value="access" />
            <select
              name="status"
              defaultValue={sp.status ?? ""}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            >
              <option value="">전체 응답코드</option>
              <option value="200">200 OK</option>
              <option value="201">201 Created</option>
              <option value="400">400 Bad Request</option>
              <option value="401">401 Unauthorized</option>
              <option value="404">404 Not Found</option>
              <option value="429">429 Too Many Requests</option>
              <option value="500">500 Internal Server Error</option>
              <option value="503">503 Service Unavailable</option>
            </select>
            <button
              type="submit"
              className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
            >
              검색
            </button>
            {sp.status && (
              <Link
                href="/system-settings/logs?tab=access"
                className="rounded-lg bg-slate-700 px-4 py-2 text-sm text-slate-300 hover:bg-slate-600"
              >
                초기화
              </Link>
            )}
          </form>

          <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">경로(path)</th>
                  <th className="px-4 py-3">메서드</th>
                  <th className="px-4 py-3">응답코드</th>
                  <th className="px-4 py-3">지연시간</th>
                  <th className="px-4 py-3">IP</th>
                  <th className="px-4 py-3">시각</th>
                </tr>
              </thead>
              <tbody>
                {accessLogs.map((log) => (
                  <tr key={log.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 font-mono text-xs text-slate-300">{log.path}</td>
                    <td className="px-4 py-3 text-xs text-slate-400">{log.method}</td>
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs ${
                          log.responseStatus >= 500
                            ? "bg-red-950/60 text-red-400"
                            : log.responseStatus >= 400
                              ? "bg-amber-950/60 text-amber-400"
                              : "bg-emerald-950/60 text-emerald-400"
                        }`}
                      >
                        {log.responseStatus}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {log.latencyMs != null ? `${log.latencyMs}ms` : "-"}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">{log.ipAddress}</td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {formatDate(log.createdAt)}
                    </td>
                  </tr>
                ))}
                {accessLogs.length === 0 && (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                      조회된 접근 로그가 없습니다.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      ) : (
        <>
          <form className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
            <input type="hidden" name="tab" value="error" />
            <select
              name="severity"
              defaultValue={sp.severity ?? ""}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            >
              <option value="">전체 등급</option>
              <option value="info">정보(info)</option>
              <option value="warning">경고(warning)</option>
              <option value="critical">긴급(critical)</option>
            </select>
            <select
              name="source"
              defaultValue={sp.source ?? ""}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            >
              <option value="">전체 소스</option>
              <option value="api">API</option>
              <option value="batch">배치</option>
              <option value="ai">AI</option>
            </select>
            <button
              type="submit"
              className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
            >
              검색
            </button>
            {(sp.severity || sp.source) && (
              <Link
                href="/system-settings/logs?tab=error"
                className="rounded-lg bg-slate-700 px-4 py-2 text-sm text-slate-300 hover:bg-slate-600"
              >
                초기화
              </Link>
            )}
            <Link
              href="/system-settings/logs?tab=error&severity=critical"
              className="rounded-lg border border-red-900 px-4 py-2 text-sm text-red-400 hover:bg-red-950/40"
            >
              🔴 긴급(critical)만 보기
            </Link>
          </form>

          <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">등급</th>
                  <th className="px-4 py-3">소스</th>
                  <th className="px-4 py-3">에러코드</th>
                  <th className="px-4 py-3">메시지</th>
                  <th className="px-4 py-3">시각</th>
                </tr>
              </thead>
              <tbody>
                {errorLogs.map((log) => (
                  <tr key={log.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3">
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs ${
                          log.severity === "critical"
                            ? "bg-red-950/60 text-red-400"
                            : log.severity === "warning"
                              ? "bg-amber-950/60 text-amber-400"
                              : "bg-slate-800 text-slate-400"
                        }`}
                      >
                        {SEVERITY_LABEL[log.severity] ?? log.severity}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-400">
                      {SOURCE_LABEL[log.source] ?? log.source}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-slate-300">
                      {log.errorCode ?? "-"}
                    </td>
                    <td className="px-4 py-3 max-w-md truncate text-xs text-slate-400">
                      {log.message}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {formatDate(log.createdAt)}
                    </td>
                  </tr>
                ))}
                {errorLogs.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                      조회된 에러 로그가 없습니다.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}

      <div className="mt-3 flex items-center justify-between text-xs text-slate-500">
        <span>
          총 {total}건 (페이지 {page}/{totalPages})
        </span>
        <div className="flex gap-2">
          {page > 1 && (
            <Link
              href={buildQuery({ page: String(page - 1) })}
              className="rounded bg-slate-800 px-3 py-1.5 hover:bg-slate-700"
            >
              이전
            </Link>
          )}
          {page < totalPages && (
            <Link
              href={buildQuery({ page: String(page + 1) })}
              className="rounded bg-slate-800 px-3 py-1.5 hover:bg-slate-700"
            >
              다음
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
