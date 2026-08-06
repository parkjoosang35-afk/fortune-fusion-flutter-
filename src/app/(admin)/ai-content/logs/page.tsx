import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.2 "AI 호출 로그 / 비용 대시보드"
// 04A G-4 ai_request_logs 기반. 09_AI_System_Design.md §9 비용/사용량 모니터링 반영.
// [주의] Firestore가 아닌 SQLite/Prisma 사용 환경이라 복합 인덱스 이슈는 없으나,
// 동일한 원칙(where 단순화 후 메모리 집계)을 적용해 group by 로직을 애플리케이션 레벨에서 처리한다.
export const dynamic = "force-dynamic";

const DOMAIN_LABEL: Record<string, string> = {
  saju: "사주풀이",
  daily: "오늘의 운세",
  tarot: "타로",
  face: "관상",
  palm: "손금",
  consultation: "AI 상담",
};

const STATUS_LABEL: Record<string, string> = {
  success: "성공",
  failed: "실패",
  timeout: "타임아웃",
};

const PAGE_SIZE = 20;

interface AiLogsPageProps {
  searchParams: Promise<{
    domain?: string;
    status?: string;
    page?: string;
  }>;
}

export default async function AiLogsPage({ searchParams }: AiLogsPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const domainFilter = params.domain ?? "";
  const statusFilter = params.status ?? "";
  const page = Math.max(1, Number(params.page ?? "1") || 1);

  const fourteenDaysAgo = new Date();
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

  // 최근 14일 전체 로그(집계용) — 단순 where(createdAt gte)만 사용, 복합 정렬은 메모리에서 처리
  const recentLogs = await prisma.aiRequestLog.findMany({
    where: { createdAt: { gte: fourteenDaysAgo } },
  });

  // ── 일별 비용/호출수 집계 (메모리) ──
  const dailyMap = new Map<string, { calls: number; cost: number; failed: number }>();
  for (const log of recentLogs) {
    const day = log.createdAt.toISOString().slice(0, 10);
    const entry = dailyMap.get(day) ?? { calls: 0, cost: 0, failed: 0 };
    entry.calls += 1;
    entry.cost += log.costEstimate ?? 0;
    if (log.status !== "success") entry.failed += 1;
    dailyMap.set(day, entry);
  }
  const dailyStats = Array.from(dailyMap.entries())
    .sort((a, b) => a[0].localeCompare(b[0]))
    .slice(-14);

  // ── 도메인별 집계 (메모리) ──
  const domainMap = new Map<string, { calls: number; cost: number; tokens: number }>();
  for (const log of recentLogs) {
    const entry = domainMap.get(log.domain) ?? { calls: 0, cost: 0, tokens: 0 };
    entry.calls += 1;
    entry.cost += log.costEstimate ?? 0;
    entry.tokens += log.tokenUsage ?? 0;
    domainMap.set(log.domain, entry);
  }
  const domainStats = Array.from(domainMap.entries()).sort((a, b) => b[1].cost - a[1].cost);

  const totalCost14d = recentLogs.reduce((sum, l) => sum + (l.costEstimate ?? 0), 0);
  const totalCalls14d = recentLogs.length;
  const failRate14d =
    totalCalls14d > 0
      ? (recentLogs.filter((l) => l.status !== "success").length / totalCalls14d) * 100
      : 0;

  // ── 상세 로그 리스트(필터+페이징) — 단순 where 조합만 사용 ──
  const where = {
    ...(domainFilter ? { domain: domainFilter } : {}),
    ...(statusFilter ? { status: statusFilter } : {}),
  };

  const [total, logs] = await Promise.all([
    prisma.aiRequestLog.count({ where }),
    prisma.aiRequestLog.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
  ]);
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const maxDailyCalls = Math.max(1, ...dailyStats.map(([, v]) => v.calls));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">AI 호출 로그 / 비용 대시보드</h1>
        <p className="mt-1 text-sm text-slate-500">
          최근 14일 기준 AI 호출량, 예상 비용, 실패율을 확인하고 상세 로그를 조회합니다.
        </p>
      </div>

      {/* 요약 카드 */}
      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <p className="text-xs text-slate-500">최근 14일 총 호출수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">
            {totalCalls14d.toLocaleString()}
          </p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <p className="text-xs text-slate-500">최근 14일 예상 비용 (USD)</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">
            ${totalCost14d.toFixed(4)}
          </p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <p className="text-xs text-slate-500">실패율 (failed/timeout)</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">
            {failRate14d.toFixed(1)}%
          </p>
        </div>
      </div>

      {/* 일별 호출량 바 차트(간단 CSS 바) */}
      <section className="mb-6 rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-slate-900">일별 호출량 추이</h2>
        <div className="flex items-end gap-2" style={{ height: 120 }}>
          {dailyStats.map(([day, v]) => (
            <div key={day} className="flex flex-1 flex-col items-center gap-1">
              <div
                className="w-full rounded-t bg-indigo-600"
                style={{ height: `${Math.max(4, (v.calls / maxDailyCalls) * 100)}px` }}
                title={`${day}: ${v.calls}건, $${v.cost.toFixed(4)}`}
              />
              <span className="text-[10px] text-slate-500">{day.slice(5)}</span>
            </div>
          ))}
        </div>
      </section>

      {/* 도메인별 비용 요약 */}
      <section className="mb-6 rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-slate-900">도메인별 비용 (최근 14일)</h2>
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="py-2 pr-4">도메인</th>
              <th className="py-2 pr-4">호출수</th>
              <th className="py-2 pr-4">토큰 사용량</th>
              <th className="py-2 pr-4">예상 비용 (USD)</th>
            </tr>
          </thead>
          <tbody>
            {domainStats.map(([domain, v]) => (
              <tr key={domain} className="border-b border-slate-200/60">
                <td className="py-2 pr-4 text-slate-700">
                  {DOMAIN_LABEL[domain] ?? domain}
                </td>
                <td className="py-2 pr-4 text-slate-500">{v.calls.toLocaleString()}</td>
                <td className="py-2 pr-4 text-slate-500">{v.tokens.toLocaleString()}</td>
                <td className="py-2 pr-4 text-slate-700">${v.cost.toFixed(4)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* 상세 로그 필터 + 목록 */}
      <form
        method="GET"
        className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-200 bg-white p-4"
      >
        <select
          name="domain"
          defaultValue={domainFilter}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 도메인</option>
          {Object.entries(DOMAIN_LABEL).map(([code, label]) => (
            <option key={code} value={code}>
              {label}
            </option>
          ))}
        </select>
        <select
          name="status"
          defaultValue={statusFilter}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 상태</option>
          <option value="success">성공</option>
          <option value="failed">실패</option>
          <option value="timeout">타임아웃</option>
        </select>
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
              <th className="px-4 py-3">일시</th>
              <th className="px-4 py-3">도메인</th>
              <th className="px-4 py-3">모델</th>
              <th className="px-4 py-3">지연(ms)</th>
              <th className="px-4 py-3">토큰</th>
              <th className="px-4 py-3">비용(USD)</th>
              <th className="px-4 py-3">상태</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  조건에 맞는 로그가 없습니다.
                </td>
              </tr>
            )}
            {logs.map((log) => (
              <tr key={log.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                <td className="px-4 py-3 text-slate-500">
                  {log.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                </td>
                <td className="px-4 py-3 text-slate-700">
                  {DOMAIN_LABEL[log.domain] ?? log.domain}
                </td>
                <td className="px-4 py-3 text-slate-500">{log.aiModel}</td>
                <td className="px-4 py-3 text-slate-500">{log.latencyMs ?? "-"}</td>
                <td className="px-4 py-3 text-slate-500">{log.tokenUsage ?? "-"}</td>
                <td className="px-4 py-3 text-slate-500">
                  {log.costEstimate?.toFixed(6) ?? "-"}
                </td>
                <td className="px-4 py-3">
                  <span
                    className={
                      log.status === "success"
                        ? "rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700"
                        : "rounded-full bg-red-100 px-2 py-1 text-xs font-medium text-red-700"
                    }
                  >
                    {STATUS_LABEL[log.status] ?? log.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* 페이징 */}
      <div className="mt-4 flex items-center justify-center gap-1">
        {Array.from({ length: totalPages }, (_, i) => i + 1)
          .slice(0, 20)
          .map((p) => (
            <a
              key={p}
              href={`/ai-content/logs?${new URLSearchParams({
                ...(domainFilter ? { domain: domainFilter } : {}),
                ...(statusFilter ? { status: statusFilter } : {}),
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
