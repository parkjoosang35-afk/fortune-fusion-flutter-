import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

// 05_Admin_System_Design.md §3.11 "시스템 설정" — 3차(마지막) 소단위: "통계 스냅샷 관리"
// (04A O-5 statistics_snapshots — 배치 실행 상태 확인, 조회 전용)
// metric_code별로 최근 실행 여부/최신 스냅샷 값을 요약해 "배치가 정상적으로
// 돌고 있는지" 한눈에 확인할 수 있는 대시보드 형태로 구성한다.
export const dynamic = "force-dynamic";

const METRIC_LABEL: Record<string, string> = {
  dau: "일간 활성 사용자(DAU)",
  point_issued_daily: "일간 포인트 지급량",
  revenue_daily: "일간 결제 매출",
  new_signup_daily: "일간 신규 가입자",
};

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

function formatValue(jsonValue: string): string {
  try {
    const parsed = JSON.parse(jsonValue) as Record<string, unknown>;
    return Object.entries(parsed)
      .map(([k, v]) => `${k}: ${v}`)
      .join(" · ");
  } catch {
    return jsonValue;
  }
}

// 오늘 날짜(YYYY-MM-DD) 기준으로 배치가 정상 실행되었는지 판정
function todayStr(): string {
  return new Date().toISOString().slice(0, 10);
}

export default async function StatisticsSnapshotsPage({
  searchParams,
}: {
  searchParams: Promise<{ metric?: string; page?: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "system_settings")) {
    redirect("/dashboard");
  }

  const sp = await searchParams;
  const PAGE_SIZE = 20;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);

  const allSnapshots = await prisma.statisticsSnapshot.findMany({
    where: { deletedAt: null },
    orderBy: [{ metricCode: "asc" }, { period: "desc" }],
  });

  // metric_code별 그룹핑 → 최신 스냅샷/오늘자 실행 여부 판정
  const metricCodes = [...new Set(allSnapshots.map((s) => s.metricCode))];
  const today = todayStr();
  const summaries = metricCodes.map((code) => {
    const items = allSnapshots.filter((s) => s.metricCode === code);
    const latest = items[0]; // period desc 정렬이므로 첫 항목이 최신
    const hasToday = items.some((s) => s.period === today);
    return { code, latest, hasToday, count: items.length };
  });

  // 필터 적용된 상세 목록(페이지네이션)
  const filtered = sp.metric ? allSnapshots.filter((s) => s.metricCode === sp.metric) : allSnapshots;
  const total = filtered.length;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const paged = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  function buildQuery(overrides: Record<string, string | undefined>) {
    const params = new URLSearchParams();
    const merged = { metric: sp.metric, page: sp.page, ...overrides };
    Object.entries(merged).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    return `/system-settings/statistics?${params.toString()}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">시스템 설정 — 통계 스냅샷 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          지표별(metric_code) 배치 집계 결과(statistics_snapshots)와 실행 상태를 확인합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/system-settings" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            전역 설정값 관리
          </Link>
          <Link href="/system-settings/logs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            접근/에러 로그 조회
          </Link>
          <Link
            href="/system-settings/statistics"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            통계 스냅샷 관리
          </Link>
        </nav>
      </div>

      {/* 배치 실행 상태 요약 카드 */}
      <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        {summaries.map((s) => (
          <div
            key={s.code}
            className={`rounded-xl border p-4 ${
              s.hasToday ? "border-slate-200 bg-white" : "border-amber-300 bg-amber-100"
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-slate-700">
                {METRIC_LABEL[s.code] ?? s.code}
              </span>
              {s.hasToday ? (
                <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                  정상
                </span>
              ) : (
                <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                  오늘자 미실행
                </span>
              )}
            </div>
            <p className="mt-2 font-mono text-xs text-slate-500">{s.code}</p>
            {s.latest && (
              <>
                <p className="mt-1 text-xs text-slate-500">최근 period: {s.latest.period}</p>
                <p className="mt-1 text-xs text-slate-500">{formatValue(s.latest.value)}</p>
                <p className="mt-1 text-xs text-slate-600">
                  마지막 실행: {formatDate(s.latest.createdAt)}
                </p>
              </>
            )}
            <p className="mt-2 text-xs text-slate-600">누적 {s.count}건</p>
            <Link
              href={`/system-settings/statistics?metric=${s.code}`}
              className="mt-2 inline-block text-xs text-indigo-700 hover:underline"
            >
              상세 이력 보기 →
            </Link>
          </div>
        ))}
        {summaries.length === 0 && (
          <p className="col-span-full text-center text-sm text-slate-500">
            아직 집계된 통계 스냅샷이 없습니다.
          </p>
        )}
      </div>

      {/* 상세 이력 필터/목록 */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <form className="flex gap-2">
          <select
            name="metric"
            defaultValue={sp.metric ?? ""}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
          >
            <option value="">전체 지표</option>
            {metricCodes.map((code) => (
              <option key={code} value={code}>
                {METRIC_LABEL[code] ?? code}
              </option>
            ))}
          </select>
          <button
            type="submit"
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
          >
            검색
          </button>
          {sp.metric && (
            <Link
              href="/system-settings/statistics"
              className="rounded-lg bg-slate-100 px-4 py-2 text-sm text-slate-600 hover:bg-slate-200"
            >
              초기화
            </Link>
          )}
        </form>
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">지표(metric_code)</th>
              <th className="px-4 py-3">기간(period)</th>
              <th className="px-4 py-3">집계값</th>
              <th className="px-4 py-3">배치 실행 시각</th>
            </tr>
          </thead>
          <tbody>
            {paged.map((s) => (
              <tr key={s.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                <td className="px-4 py-3 text-slate-700">{METRIC_LABEL[s.metricCode] ?? s.metricCode}</td>
                <td className="px-4 py-3 font-mono text-xs text-slate-500">{s.period}</td>
                <td className="px-4 py-3 text-xs text-slate-500">{formatValue(s.value)}</td>
                <td className="px-4 py-3 text-xs text-slate-500">{formatDate(s.createdAt)}</td>
              </tr>
            ))}
            {paged.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                  조회된 통계 스냅샷이 없습니다.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="mt-3 flex items-center justify-between text-xs text-slate-500">
        <span>
          총 {total}건 (페이지 {page}/{totalPages})
        </span>
        <div className="flex gap-2">
          {page > 1 && (
            <Link
              href={buildQuery({ page: String(page - 1) })}
              className="rounded bg-white px-3 py-1.5 hover:bg-slate-200"
            >
              이전
            </Link>
          )}
          {page < totalPages && (
            <Link
              href={buildQuery({ page: String(page + 1) })}
              className="rounded bg-white px-3 py-1.5 hover:bg-slate-200"
            >
              다음
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
