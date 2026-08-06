import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import AdminUserCreateForm from "@/components/AdminUserCreateForm";
import AdminUserRow from "@/components/AdminUserRow";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 1차 소단위: "관리자 계정 관리"
// (04A B-1 admin_users CRUD, 역할(role) 배정 — 역할 변경은 2단계 확인 필수)
// 08_Web_Design.md §3.2 라우트 매핑표: 운영/보안 → /admin-users, /admin-users/roles, /audit-logs
export const dynamic = "force-dynamic";

export default async function AdminUsersPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/dashboard");
  }

  const canWrite = canWriteMenu(session.roleCode, "ops_security");
  const canDelete = canDeleteMenu(session.roleCode, "ops_security");

  const [adminUsers, roles] = await Promise.all([
    prisma.adminUser.findMany({
      where: { deletedAt: null },
      include: { role: true },
      orderBy: { createdAt: "asc" },
    }),
    prisma.adminRole.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } }),
  ]);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">운영/보안 — 관리자 계정 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          관리자 계정(admin_users)을 관리하고 역할(role)을 배정합니다. 역할 변경은 사유 입력과
          본인 비밀번호 재확인(2단계 확인)이 필요합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link
            href="/admin-users"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
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
          <Link href="/audit-logs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            감사로그(Audit) 조회
          </Link>
        </nav>
      </div>

      <AdminUserCreateForm
        roles={roles.map((r) => ({ id: r.id, code: r.code, name: r.name }))}
        canWrite={canWrite}
      />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">이메일(로그인 ID)</th>
              <th className="px-4 py-3">이름 / 2FA</th>
              <th className="px-4 py-3">역할</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">최근 로그인</th>
              <th className="px-4 py-3">작업</th>
            </tr>
          </thead>
          <tbody>
            {adminUsers.map((u) => (
              <AdminUserRow
                key={u.id}
                adminUser={{
                  id: u.id,
                  email: u.email,
                  name: u.name,
                  roleId: u.roleId,
                  roleCode: u.role.code,
                  roleName: u.role.name,
                  is2faEnabled: u.is2faEnabled,
                  status: u.status,
                  lastLoginAt: u.lastLoginAt,
                }}
                roles={roles.map((r) => ({ id: r.id, code: r.code, name: r.name }))}
                isSelf={u.id === session.adminUserId}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-500">총 관리자 계정 {adminUsers.length}건</p>
    </div>
  );
}
