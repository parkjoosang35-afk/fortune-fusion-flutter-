"use server";

// 05_Admin_System_Design.md §3.10 "운영/보안" — 1차 소단위: 관리자 계정 관리
// 04A B-1 admin_users CRUD, 역할(role) 배정.
// [설계 결정] "역할 변경은 2단계 확인 필수"(05§3.10, §4.5 워크플로우) —
// super_admin 본인의 현재 비밀번호 재입력을 2단계 확인 수단으로 채택한다
// (04A B-1에 admin_users.is_2fa_enabled가 있으나 2FA 실제 인증 흐름은 이번
// 소단위 범위를 벗어나므로, 원칙④ 준수를 위해 비밀번호 재확인으로 축소 구현).
// ops_security 메뉴는 05§5.2 매트릭스상 super_admin만 RWD, 나머지는 전부 X.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteOpsSecurity(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ops_security");
}

function canDeleteOpsSecurity(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "ops_security");
}

export interface AdminUserFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
const CreateAdminUserSchema = z.object({
  email: z.string().min(1, "이메일(로그인 ID)을 입력해주세요.(04A B-1 명시: NOT NULL, UNIQUE)"),
  name: z.string().min(1, "이름을 입력해주세요.(04A B-1 명시: NOT NULL)"),
  password: z.string().min(8, "비밀번호는 8자 이상이어야 합니다."),
  roleId: z.coerce.number().int().positive("역할을 선택해주세요."),
  is2faEnabled: z.coerce.boolean().optional().default(false),
});

export async function createAdminUser(
  _prevState: AdminUserFormState,
  formData: FormData
): Promise<AdminUserFormState> {
  const session = await verifyAdminSession();
  if (!canWriteOpsSecurity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다.(운영/보안은 super_admin 전용)" };
  }

  const parsed = CreateAdminUserSchema.safeParse({
    email: formData.get("email"),
    name: formData.get("name"),
    password: formData.get("password"),
    roleId: formData.get("roleId"),
    is2faEnabled: formData.get("is2faEnabled") === "on" || formData.get("is2faEnabled") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const dup = await prisma.adminUser.findUnique({ where: { email: parsed.data.email } });
  if (dup) {
    return { error: "이미 존재하는 이메일(로그인 ID)입니다.(04A B-1 명시: UNIQUE)" };
  }

  const role = await prisma.adminRole.findUnique({ where: { id: parsed.data.roleId } });
  if (!role || role.deletedAt) {
    return { error: "존재하지 않는 역할입니다." };
  }

  const passwordHash = await bcrypt.hash(parsed.data.password, 10);

  const created = await prisma.adminUser.create({
    data: {
      email: parsed.data.email,
      name: parsed.data.name,
      passwordHash,
      roleId: parsed.data.roleId,
      is2faEnabled: parsed.data.is2faEnabled,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "admin_user",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ email: created.email, name: created.name, roleCode: role.code }),
    },
  });

  revalidatePath("/admin-users");
  return { success: true };
}

// ── 수정(이름/2FA만 — 이메일/비밀번호/역할은 별도 액션으로 분리) ──
const UpdateAdminUserSchema = z.object({
  id: z.coerce.number().int().positive(),
  name: z.string().min(1, "이름을 입력해주세요."),
  is2faEnabled: z.coerce.boolean().optional().default(false),
});

export async function updateAdminUser(
  _prevState: AdminUserFormState,
  formData: FormData
): Promise<AdminUserFormState> {
  const session = await verifyAdminSession();
  if (!canWriteOpsSecurity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateAdminUserSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    is2faEnabled: formData.get("is2faEnabled") === "on" || formData.get("is2faEnabled") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.adminUser.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 관리자 계정입니다." };
  }

  const after = await prisma.adminUser.update({
    where: { id: parsed.data.id },
    data: { name: parsed.data.name, is2faEnabled: parsed.data.is2faEnabled, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "admin_user",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name, is2faEnabled: before.is2faEnabled }),
      after: JSON.stringify({ name: after.name, is2faEnabled: after.is2faEnabled }),
    },
  });

  revalidatePath("/admin-users");
  return { success: true };
}

// ── 역할 변경 (2단계 확인: 요청자 본인의 현재 비밀번호 재입력 필수) ──
const ChangeRoleSchema = z.object({
  id: z.coerce.number().int().positive(),
  newRoleId: z.coerce.number().int().positive("변경할 역할을 선택해주세요."),
  reason: z.string().min(1, "역할 변경 사유를 입력해주세요.(05§4.5 워크플로우 명시: 사유 입력 필수)"),
  confirmPassword: z.string().min(1, "2단계 확인을 위해 본인 비밀번호를 입력해주세요."),
});

export async function changeAdminUserRole(
  _prevState: AdminUserFormState,
  formData: FormData
): Promise<AdminUserFormState> {
  const session = await verifyAdminSession();
  if (!canWriteOpsSecurity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ChangeRoleSchema.safeParse({
    id: formData.get("id"),
    newRoleId: formData.get("newRoleId"),
    reason: formData.get("reason"),
    confirmPassword: formData.get("confirmPassword"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  // 2단계 확인: 요청자(super_admin) 본인의 현재 비밀번호 검증
  const requester = await prisma.adminUser.findUnique({ where: { id: session.adminUserId } });
  if (!requester) {
    return { error: "요청자 계정을 확인할 수 없습니다." };
  }
  const passwordOk = await bcrypt.compare(parsed.data.confirmPassword, requester.passwordHash);
  if (!passwordOk) {
    return { error: "본인 확인에 실패했습니다.(비밀번호가 올바르지 않습니다)" };
  }

  const before = await prisma.adminUser.findUnique({
    where: { id: parsed.data.id },
    include: { role: true },
  });
  if (!before) {
    return { error: "존재하지 않는 관리자 계정입니다." };
  }

  const newRole = await prisma.adminRole.findUnique({ where: { id: parsed.data.newRoleId } });
  if (!newRole || newRole.deletedAt) {
    return { error: "존재하지 않는 역할입니다." };
  }

  await prisma.adminUser.update({
    where: { id: parsed.data.id },
    data: { roleId: parsed.data.newRoleId, updatedBy: session.email },
  });

  // 05§4.5: "operation_logs 기록" — after에 변경 사유 포함(신규 컬럼 불필요, JSON 필드 활용 — 05§6 결정 재사용)
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "role_change",
      targetType: "admin_user",
      targetId: parsed.data.id,
      before: JSON.stringify({ roleCode: before.role.code }),
      after: JSON.stringify({ roleCode: newRole.code, reason: parsed.data.reason }),
    },
  });

  revalidatePath("/admin-users");
  return { success: true };
}

// ── 상태 변경(활성/비활성) ──
const ToggleStatusSchema = z.object({
  id: z.coerce.number().int().positive(),
  newStatus: z.enum(["active", "suspended"]),
});

export async function toggleAdminUserStatus(
  _prevState: AdminUserFormState,
  formData: FormData
): Promise<AdminUserFormState> {
  const session = await verifyAdminSession();
  if (!canWriteOpsSecurity(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleStatusSchema.safeParse({
    id: formData.get("id"),
    newStatus: formData.get("newStatus"),
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  if (parsed.data.id === session.adminUserId) {
    return { error: "본인 계정의 상태는 변경할 수 없습니다." };
  }

  const before = await prisma.adminUser.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 관리자 계정입니다." };
  }

  await prisma.adminUser.update({
    where: { id: parsed.data.id },
    data: { status: parsed.data.newStatus, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.newStatus === "active" ? "activate" : "suspend",
      targetType: "admin_user",
      targetId: parsed.data.id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: parsed.data.newStatus }),
    },
  });

  revalidatePath("/admin-users");
  return { success: true };
}

// ── 삭제(soft delete) ──
const DeleteAdminUserSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteAdminUser(
  _prevState: AdminUserFormState,
  formData: FormData
): Promise<AdminUserFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteOpsSecurity(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteAdminUserSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  if (parsed.data.id === session.adminUserId) {
    return { error: "본인 계정은 삭제할 수 없습니다." };
  }

  const before = await prisma.adminUser.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 관리자 계정입니다." };
  }

  await prisma.adminUser.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "admin_user",
      targetId: parsed.data.id,
      before: JSON.stringify({ email: before.email }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/admin-users");
  return { success: true };
}
