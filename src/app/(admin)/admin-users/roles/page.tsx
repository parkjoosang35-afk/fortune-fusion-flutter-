import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, ADMIN_MENU_GROUPS } from "@/lib/rbac";
import PermissionMatrixCell from "@/components/PermissionMatrixCell";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 2차 소단위: "역할/권한 매트릭스"
// (04A B-2 admin_roles, B-3 admin_permissions — 메뉴별 read/write/delete 체크박스 매트릭스 편집)
//
// [설계 결정 — 방안 A, 사용자 승인("진행")] admin_permissions는 04A 스펙대로 조회+편집을
// 제공하나, 실제 접근 제어(rbac.ts RBAC_MATRIX)는 코드 상수 기준이라 이 화면의 저장값이
// 즉시 접근 제어에 반영되지 않는다. 사용자를 오도하지 않기 위해 안내 배너를 명시한다.
export const dynamic = "force-dynamic";

export default async function AdminRolesPermissionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "ops_security");

  const [roles, permissions] = await Promise.all([
    prisma.adminRole.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } }),
    prisma.adminPermission.findMany({ where: { deletedAt: null } }),
  ]);

  const menuCodes = ADMIN_MENU_GROUPS.map((m) => m.code);

  function findPerm(roleId: number, menuCode: string) {
    return permissions.find((p) => p.roleId === roleId && p.menuCode === menuCode);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">운영/보안 — 역할/권한 매트릭스</h1>
        <p className="mt-1 text-sm text-slate-500">
          역할(admin_roles)별 메뉴 접근 권한(admin_permissions: read/write/delete)을 조회하고
          편집합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/admin-users" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            관리자 계정 관리
          </Link>
          <Link
            href="/admin-users/roles"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
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

      <div className="mb-4 rounded-lg border border-amber-300 bg-amber-100 px-4 py-3 text-xs text-amber-800">
        ⚠ 주의: 이 화면에서 저장한 권한 값은 <span className="font-semibold">admin_permissions</span> 테이블에는
        정상 반영되지만, 현재 시스템의 실제 메뉴 접근 제어는 배포된 코드 기준(정적 권한
        매트릭스)으로 동작합니다. 따라서 이 화면에서의 편집이 실제 로그인 세션의 접근 권한에
        <span className="font-semibold"> 즉시 반영되지 않을 수 있습니다.</span> 실제 접근 제어 기준을
        변경하려면 별도의 코드 배포가 필요합니다. (참고/기록용 편집 화면)
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">메뉴</th>
              {roles.map((r) => (
                <th key={r.id} className="px-3 py-3 text-center">
                  {r.name}
                  <div className="text-[10px] font-normal normal-case text-slate-600">
                    ({r.code})
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {menuCodes.map((menuCode) => {
              const menuLabel =
                ADMIN_MENU_GROUPS.find((m) => m.code === menuCode)?.label ?? menuCode;
              return (
                <tr key={menuCode} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-2 text-slate-700">{menuLabel}</td>
                  {roles.map((r) => {
                    const perm = findPerm(r.id, menuCode);
                    return (
                      <PermissionMatrixCell
                        key={`${r.id}-${menuCode}`}
                        roleId={r.id}
                        menuCode={menuCode}
                        canRead={perm?.canRead ?? false}
                        canWrite={perm?.canWrite ?? false}
                        canDelete={perm?.canDelete ?? false}
                        editable={canWrite}
                      />
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-500">
        R=조회, W=생성/수정, D=삭제. 셀을 클릭하면 편집할 수 있습니다.
        {!canWrite && " (조회 전용 — super_admin만 편집 가능)"}
      </p>
    </div>
  );
}
