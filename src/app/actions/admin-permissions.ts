"use server";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 2차 소단위: 역할/권한 매트릭스
// (04A B-2 admin_roles, B-3 admin_permissions — 메뉴별 read/write/delete 체크박스 매트릭스 편집)
//
// [중요 설계 결정 — 원칙② 설계충돌 방지, 사용자 승인("진행") 하 방안 A로 진행]
// 현재 실제 RBAC 접근 제어(src/lib/rbac.ts의 canAccessMenu/canWriteMenu/canDeleteMenu)는
// 코드에 하드코딩된 RBAC_MATRIX 상수를 기준으로 동작하며, DB(admin_permissions)를
// 조회하지 않는다. RBAC_MATRIX를 DB 기반 비동기 조회로 전환하는 것은 이미 완료·검증된
// 9개 메뉴/30여 개 화면 전체의 회귀 리스크를 동반하는 대규모 리팩토링이므로 이번
// 소단위 범위를 벗어난다(원칙④·⑦).
// 따라서 이 화면은 "admin_permissions 테이블의 조회 + 편집(저장)"까지는 04A B-3 스펙대로
// 정상 구현하되, 저장된 값이 실제 접근 제어에 "즉시 반영되지 않는다"는 점을 화면에
// 명확히 안내한다(사용자를 오도하지 않기 위한 조치). 실제 접근 제어 기준 변경은
// rbac.ts의 RBAC_MATRIX 상수를 코드 배포로 수정해야 한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

export interface PermissionFormState {
  error?: string;
  success?: boolean;
}

const UpdatePermissionSchema = z.object({
  roleId: z.coerce.number().int().positive(),
  menuCode: z.string().min(1),
  canRead: z.coerce.boolean().optional().default(false),
  canWrite: z.coerce.boolean().optional().default(false),
  canDelete: z.coerce.boolean().optional().default(false),
});

export async function updateAdminPermission(
  _prevState: PermissionFormState,
  formData: FormData
): Promise<PermissionFormState> {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "ops_security")) {
    return { error: "이 작업을 수행할 권한이 없습니다.(운영/보안은 super_admin 전용)" };
  }

  const parsed = UpdatePermissionSchema.safeParse({
    roleId: formData.get("roleId"),
    menuCode: formData.get("menuCode"),
    canRead: formData.get("canRead") === "on" || formData.get("canRead") === "true",
    canWrite: formData.get("canWrite") === "on" || formData.get("canWrite") === "true",
    canDelete: formData.get("canDelete") === "on" || formData.get("canDelete") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  // write 없이 delete만 켜는 등 논리적으로 불가능한 조합 방지(04A 스펙상 강제 제약은
  // 없으나, write 없는 delete는 UI/UX상 무의미하므로 방어적으로 write도 함께 요구)
  if (parsed.data.canDelete && !parsed.data.canWrite) {
    return { error: "삭제 권한은 쓰기 권한과 함께만 부여할 수 있습니다." };
  }

  const before = await prisma.adminPermission.findUnique({
    where: { roleId_menuCode: { roleId: parsed.data.roleId, menuCode: parsed.data.menuCode } },
  });
  if (!before) {
    return { error: "존재하지 않는 권한 레코드입니다.(role_id + menu_code 조합)" };
  }

  const role = await prisma.adminRole.findUnique({ where: { id: parsed.data.roleId } });

  const after = await prisma.adminPermission.update({
    where: { roleId_menuCode: { roleId: parsed.data.roleId, menuCode: parsed.data.menuCode } },
    data: {
      canRead: parsed.data.canRead,
      canWrite: parsed.data.canWrite,
      canDelete: parsed.data.canDelete,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "admin_permission",
      targetId: after.id,
      before: JSON.stringify({
        roleCode: role?.code,
        menuCode: before.menuCode,
        canRead: before.canRead,
        canWrite: before.canWrite,
        canDelete: before.canDelete,
      }),
      after: JSON.stringify({
        roleCode: role?.code,
        menuCode: after.menuCode,
        canRead: after.canRead,
        canWrite: after.canWrite,
        canDelete: after.canDelete,
      }),
    },
  });

  revalidatePath("/admin-users/roles");
  return { success: true };
}
