import { redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import {
  canAccessMenu,
  ADMIN_ROLE_CODES,
  RBAC_MATRIX,
  MENU_CODE_LABELS,
  getAllMenuCodes,
  type AdminRoleCode,
} from "@/lib/rbac";
import OpsSystemSubNav from "@/components/OpsSystemSubNav";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 2차 소단위: "역할/권한 매트릭스"
// (04A B-2 admin_roles, B-3 admin_permissions — 메뉴별 read/write/delete 체크박스 매트릭스)
//
// [2026-11-11 신통방통 관리자 2.0 전면 재설계 - Task9a "조회 전용 전환"]
// 과거(방안 A) 설계는 "admin_permissions DB 테이블은 편집 가능하지만 실제 접근
// 제어는 코드(rbac.ts RBAC_MATRIX)가 담당해 저장값이 반영되지 않는다"는 구조적
// 모순을 안고 있었다(보고서⑩ §1 설계원칙5 "숨김 메뉴 원칙 폐지" 및 보고서⑨에서
// 지적된 "편집 가능해 보이지만 실제로는 아무 효과가 없는 화면"). 사용자가
// "보고서대로 실행"을 명시적으로 지시했으므로, 이번에 이 화면을 완전히
// 조회 전용으로 전환하고, 더는 신뢰할 수 없는 admin_permissions DB 편집
// 기능(PermissionMatrixCell의 편집 모드, updateAdminPermission 호출)을 이 화면에서
// 제거한다. 대신 "실제로 지금 적용 중인" 유일한 권한 소스인 RBAC_MATRIX
// 코드 상수를 직접 테이블로 렌더링해 대표자가 혼동 없이 "진짜 권한"을 확인할
// 수 있게 한다. admin_permissions DB 테이블은 과거 저장된 기록 조회용으로만
// 하단에 별도 섹션으로 남겨둔다(완전 삭제하지 않음 — 04A B-3 스펙 보존).
//
// [코드/파일 영향 범위] updateAdminPermission 서버 액션과 PermissionMatrixCell
// 컴포넌트 자체는 삭제하지 않는다(다른 화면에서 참조하지 않지만, DB 스키마
// 레벨 CRUD 자체를 금지할 근거는 없어 "화면에서만 편집 진입점 제거" 원칙 적용 —
// 이번 삭제 작업들과 동일한 "off" 패턴).
export const dynamic = "force-dynamic";

const ROLE_LABEL: Record<AdminRoleCode, string> = {
  super_admin: "최고관리자",
  operator: "운영자",
  cs: "고객지원",
  content_manager: "콘텐츠매니저",
};

export default async function AdminRolesPermissionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/dashboard");
  }
  const canAccessSystemSettingsFlag = canAccessMenu(session.roleCode, "system_settings");

  // [조회 전용 전환] admin_permissions DB 레코드는 "과거 기록 참고용" 하단
  // 섹션에서만 보여준다 — 실제 권한 판정에는 전혀 쓰이지 않는다는 점을
  // 명확히 하기 위해 메인 테이블과 분리했다.
  const [roles, permissions] = await Promise.all([
    prisma.adminRole.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } }),
    prisma.adminPermission.findMany({ where: { deletedAt: null } }),
  ]);

  const menuCodes = getAllMenuCodes();

  function findDbPerm(roleId: number, menuCode: string) {
    return permissions.find((p) => p.roleId === roleId && p.menuCode === menuCode);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">AI시스템관리 — 역할/권한 매트릭스(조회전용)</h1>
        <p className="mt-1 text-sm text-slate-500">
          현재 코드에 배포되어 실제로 적용 중인 역할별 메뉴 접근 권한(read/write/delete)을
          조회합니다.
        </p>
        <OpsSystemSubNav
          canAccessOpsSecurity={true}
          canAccessSystemSettings={canAccessSystemSettingsFlag}
        />
      </div>

      <div className="mb-4 rounded-lg border border-emerald-300 bg-emerald-50 px-4 py-3 text-xs text-emerald-800">
        ✅ 2026-11-11 관리자 2.0 재설계로 이 화면은 <span className="font-semibold">조회 전용</span>으로
        전환되었습니다. 아래 표는 <span className="font-semibold">코드(src/lib/rbac.ts RBAC_MATRIX)</span>에
        실제로 배포되어 지금 이 순간 적용 중인 권한을 그대로 보여줍니다. 권한을 변경하려면
        코드 수정 후 재배포가 필요합니다(과거처럼 화면에서 체크박스를 눌러도 실제 접근
        제어에는 반영되지 않는 혼동을 방지하기 위한 조치).
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">메뉴 코드</th>
              {ADMIN_ROLE_CODES.map((rc) => (
                <th key={rc} className="px-3 py-3 text-center">
                  {ROLE_LABEL[rc]}
                  <div className="text-[10px] font-normal normal-case text-slate-600">({rc})</div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {menuCodes.map((menuCode) => {
              const menuLabel = MENU_CODE_LABELS[menuCode] ?? menuCode;
              const row = RBAC_MATRIX[menuCode];
              return (
                <tr key={menuCode} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-2 text-slate-700">
                    {menuLabel}
                    <div className="text-[10px] text-slate-400">{menuCode}</div>
                  </td>
                  {ADMIN_ROLE_CODES.map((rc) => {
                    const perm = row[rc];
                    return (
                      <td key={rc} className="px-3 py-2 text-center font-mono text-xs text-slate-600">
                        {perm.read ? "R" : "-"}
                        {perm.write ? "W" : "-"}
                        {perm.delete ? "D" : "-"}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-500">
        R=조회, W=생성/수정, D=삭제. [그룹] 접두사가 붙은 행은 6개 최상위 사이드바
        그룹의 "펼침 자격" 판정용 가상 코드이며, 실제 화면 접근은 하위 리프 메뉴의
        고유 코드가 최종 판정합니다.
      </p>

      {/* [DB 기록 참고용] admin_permissions 테이블 — 실제 권한 판정에는 쓰이지 않음 */}
      <details className="mt-8 rounded-xl border border-slate-200 bg-slate-50 p-4">
        <summary className="cursor-pointer text-sm font-semibold text-slate-700">
          참고: admin_permissions DB 기록 (저장된 과거 값, 실제 권한 판정에 미사용)
        </summary>
        <div className="mt-3 overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">메뉴 코드</th>
                {roles.map((r) => (
                  <th key={r.id} className="px-3 py-3 text-center">
                    {r.name}
                    <div className="text-[10px] font-normal normal-case text-slate-600">({r.code})</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {menuCodes.map((menuCode) => (
                <tr key={menuCode} className="border-b border-slate-200/60">
                  <td className="px-4 py-2 text-slate-500">{MENU_CODE_LABELS[menuCode] ?? menuCode}</td>
                  {roles.map((r) => {
                    const perm = findDbPerm(r.id, menuCode);
                    return (
                      <td key={r.id} className="px-3 py-2 text-center font-mono text-xs text-slate-400">
                        {perm?.canRead ? "R" : "-"}
                        {perm?.canWrite ? "W" : "-"}
                        {perm?.canDelete ? "D" : "-"}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </div>
  );
}
