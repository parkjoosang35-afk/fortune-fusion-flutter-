import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import AuditDiffViewer from "@/components/AuditDiffViewer";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 4차(마지막) 소단위: "감사로그(Audit) 조회"
// (04A O-2 operation_logs — actor/action/target/before-after 스냅샷 조회,
//  필터(기간/관리자/액션유형))
// 08_Web_Design.md §3.2 라우트: /audit-logs, §3.4 AuditTrailViewer(diff 뷰어) 재사용
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;

const ACTION_LABEL: Record<string, string> = {
  create: "생성",
  update: "수정",
  delete: "삭제",
  deploy: "배포",
  role_change: "역할변경",
  activate: "활성화",
  suspend: "정지",
};

export default async function AuditLogsPage({
  searchParams,
}: {
  searchParams: Promise<{
    actorId?: string;
    action?: string;
    targetType?: string;
    startDate?: string;
    endDate?: string;
    page?: string;
  }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/dashboard");
  }

  const sp = await searchParams;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);

  const where: {
    actorId?: number;
    action?: string;
    targetType?: string;
    createdAt?: { gte?: Date; lte?: Date };
  } = {};
  if (sp.actorId) where.actorId = parseInt(sp.actorId, 10);
  if (sp.action) where.action = sp.action;
  if (sp.targetType) where.targetType = sp.targetType;
  if (sp.startDate || sp.endDate) {
    where.createdAt = {};
    if (sp.startDate) where.createdAt.gte = new Date(`${sp.startDate}T00:00:00`);
    if (sp.endDate) where.createdAt.lte = new Date(`${sp.endDate}T23:59:59`);
  }

  const [logs, total, adminUsers, distinctActions, distinctTargetTypes] = await Promise.all([
    prisma.operationLog.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
    prisma.operationLog.count({ where }),
    prisma.adminUser.findMany({ where: { deletedAt: null }, orderBy: { name: "asc" } }),
    prisma.operationLog.findMany({ distinct: ["action"], select: { action: true } }),
    prisma.operationLog.findMany({ distinct: ["targetType"], select: { targetType: true } }),
  ]);

  // actorId → 관리자 이름 매핑(메모리, 복합 join 회피 — 기존 전례 재사용)
  const adminMap = new Map(adminUsers.map((u) => [u.id, u]));

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  function buildQuery(overrides: Record<string, string | undefined>) {
    const params = new URLSearchParams();
    const merged = {
      actorId: sp.actorId,
      action: sp.action,
      targetType: sp.targetType,
      startDate: sp.startDate,
      endDate: sp.endDate,
      page: sp.page,
      ...overrides,
    };
    Object.entries(merged).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    return `/audit-logs?${params.toString()}`;
  }

  function formatDate(d: Date): string {
    return d.toISOString().slice(0, 19).replace("T", " ");
  }

  const hasFilters = sp.actorId || sp.action || sp.targetType || sp.startDate || sp.endDate;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">운영/보안 — 감사로그(Audit) 조회</h1>
        <p className="mt-1 text-sm text-slate-500">
          관리자의 모든 생성/수정/삭제 작업 이력(operation_logs)을 before/after 스냅샷과
          함께 조회합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/admin-users" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            관리자 계정 관리
          </Link>
          <Link href="/admin-users/roles" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            역할/권한 매트릭스
          </Link>
          <Link
            href="/admin-users/login-logs"
            className="px-3 py-2 text-slate-500 hover:text-slate-900"
          >
            관리자 로그인 이력
          </Link>
          <Link
            href="/audit-logs"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            감사로그(Audit) 조회
          </Link>
        </nav>
      </div>

      <form className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-200 bg-white p-4">
        <select
          name="actorId"
          defaultValue={sp.actorId ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
        >
          <option value="">전체 관리자</option>
          {adminUsers.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name} ({u.email})
            </option>
          ))}
        </select>
        <select
          name="action"
          defaultValue={sp.action ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
        >
          <option value="">전체 액션</option>
          {distinctActions.map((a) => (
            <option key={a.action} value={a.action}>
              {ACTION_LABEL[a.action] ?? a.action}
            </option>
          ))}
        </select>
        <select
          name="targetType"
          defaultValue={sp.targetType ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
        >
          <option value="">전체 대상</option>
          {distinctTargetTypes.map((t) => (
            <option key={t.targetType} value={t.targetType}>
              {t.targetType}
            </option>
          ))}
        </select>
        <input
          type="date"
          name="startDate"
          defaultValue={sp.startDate ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
        />
        <span className="self-center text-slate-500">~</span>
        <input
          type="date"
          name="endDate"
          defaultValue={sp.endDate ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
        />
        <button
          type="submit"
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
        >
          검색
        </button>
        {hasFilters && (
          <Link
            href="/audit-logs"
            className="rounded-lg bg-slate-100 px-4 py-2 text-sm text-slate-600 hover:bg-slate-200"
          >
            초기화
          </Link>
        )}
      </form>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">시각</th>
              <th className="px-4 py-3">관리자(actor)</th>
              <th className="px-4 py-3">액션</th>
              <th className="px-4 py-3">대상(target)</th>
              <th className="px-4 py-3">변경 내용(before → after)</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => {
              const actor = log.actorId ? adminMap.get(log.actorId) : undefined;
              return (
                <tr key={log.id} className="border-b border-slate-200/60 align-top hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-xs text-slate-500">{formatDate(log.createdAt)}</td>
                  <td className="px-4 py-3 text-slate-700">
                    {actor ? (
                      <>
                        {actor.name}
                        <span className="ml-1 text-xs text-slate-500">({actor.email})</span>
                      </>
                    ) : (
                      <span className="text-slate-500">
                        {log.actorType}#{log.actorId ?? "-"}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-800">
                      {ACTION_LABEL[log.action] ?? log.action}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">
                    {log.targetType}
                    {log.targetId != null && <span className="text-slate-600"> #{log.targetId}</span>}
                  </td>
                  <td className="px-4 py-3">
                    <AuditDiffViewer before={log.before} after={log.after} />
                  </td>
                </tr>
              );
            })}
            {logs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                  조회된 감사로그가 없습니다.
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
