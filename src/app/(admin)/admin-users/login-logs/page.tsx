import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 3차 소단위: "관리자 로그인 이력"
// (04A B-4 admin_login_logs — Append-only, 조회 전용)
// auth.ts의 login() 액션에서 성공/실패 모두 이미 기록 중이므로 별도 Server Action 불필요.
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;

export default async function AdminLoginLogsPage({
  searchParams,
}: {
  searchParams: Promise<{ adminUserId?: string; result?: string; page?: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/dashboard");
  }

  const sp = await searchParams;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const adminUserIdFilter = sp.adminUserId ? parseInt(sp.adminUserId, 10) : undefined;
  const resultFilter = sp.result; // "success" | "failure" | undefined

  const where: {
    adminUserId?: number;
    successFlag?: boolean;
  } = {};
  if (adminUserIdFilter) where.adminUserId = adminUserIdFilter;
  if (resultFilter === "success") where.successFlag = true;
  if (resultFilter === "failure") where.successFlag = false;

  const [logs, total, adminUsers] = await Promise.all([
    prisma.adminLoginLog.findMany({
      where,
      include: { adminUser: true },
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
    prisma.adminLoginLog.count({ where }),
    prisma.adminUser.findMany({ where: { deletedAt: null }, orderBy: { name: "asc" } }),
  ]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  function buildQuery(overrides: Record<string, string | undefined>) {
    const params = new URLSearchParams();
    const merged = {
      adminUserId: sp.adminUserId,
      result: sp.result,
      page: sp.page,
      ...overrides,
    };
    Object.entries(merged).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    return `/admin-users/login-logs?${params.toString()}`;
  }

  function formatDate(d: Date): string {
    return d.toISOString().slice(0, 19).replace("T", " ");
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">운영/보안 — 관리자 로그인 이력</h1>
        <p className="mt-1 text-sm text-slate-400">
          관리자 계정의 로그인 시도 이력(admin_login_logs)을 조회합니다. 성공/실패 모두
          기록되는 Append-only 로그입니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/admin-users" className="px-3 py-2 text-slate-400 hover:text-white">
            관리자 계정 관리
          </Link>
          <Link href="/admin-users/roles" className="px-3 py-2 text-slate-400 hover:text-white">
            역할/권한 매트릭스
          </Link>
          <Link
            href="/admin-users/login-logs"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            관리자 로그인 이력
          </Link>
          <Link href="/audit-logs" className="px-3 py-2 text-slate-400 hover:text-white">
            감사로그(Audit) 조회
          </Link>
        </nav>
      </div>

      <form className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <select
          name="adminUserId"
          defaultValue={sp.adminUserId ?? ""}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
        >
          <option value="">전체 관리자</option>
          {adminUsers.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name} ({u.email})
            </option>
          ))}
        </select>
        <select
          name="result"
          defaultValue={sp.result ?? ""}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
        >
          <option value="">전체 결과</option>
          <option value="success">성공</option>
          <option value="failure">실패</option>
        </select>
        <button
          type="submit"
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
        >
          검색
        </button>
        {(sp.adminUserId || sp.result) && (
          <Link
            href="/admin-users/login-logs"
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
              <th className="px-4 py-3">관리자</th>
              <th className="px-4 py-3">IP 주소</th>
              <th className="px-4 py-3">결과</th>
              <th className="px-4 py-3">시각</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                <td className="px-4 py-3 text-slate-200">
                  {log.adminUser.name}
                  <span className="ml-1 text-xs text-slate-500">({log.adminUser.email})</span>
                </td>
                <td className="px-4 py-3 text-slate-400">{log.ipAddress}</td>
                <td className="px-4 py-3">
                  {log.successFlag ? (
                    <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
                      성공
                    </span>
                  ) : (
                    <span className="rounded-full bg-red-950/60 px-2 py-0.5 text-xs text-red-400">
                      실패
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 text-xs text-slate-500">{formatDate(log.createdAt)}</td>
              </tr>
            ))}
            {logs.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                  조회된 로그인 이력이 없습니다.
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
