"use server";

// 시스템 설정 — 전역 설정값 관리 Server Actions
// 05_Admin_System_Design.md §3.11 "전역 설정값 관리" — 04A O-1 system_settings CRUD
// (key-value, 예: 서비스 점검모드 on/off, 최소 앱버전). notices.ts/point-policies.ts
// 패턴을 그대로 재사용한다. value는 JSONB → SQLite에서는 JSON 문자열로 저장.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteSystemSettings(roleCode: string): boolean {
  return canWriteMenu(roleCode, "system_settings");
}

function canDeleteSystemSettings(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "system_settings");
}

export interface SystemSettingFormState {
  error?: string;
  success?: boolean;
}

// value는 사용자가 입력한 원시 문자열을 그대로 받되, JSON으로 파싱 가능하면 파싱된
// 형태로 재직렬화(정규화)하고, 파싱 불가하면 단순 문자열 값으로 JSON.stringify한다.
// 이렇게 하면 "true"/"1.2.3"/"{"a":1}" 등 다양한 입력을 모두 유효한 JSON으로 저장할 수 있다.
function normalizeValueToJson(raw: string): string {
  try {
    JSON.parse(raw);
    return raw; // 이미 유효한 JSON 문자열(예: "true", "123", "{...}")
  } catch {
    return JSON.stringify(raw); // 순수 문자열(예: "1.0.0")은 JSON 문자열로 감싼다
  }
}

const KeySchema = z
  .string()
  .min(1, "설정 키를 입력해주세요.")
  .regex(/^[a-z0-9_.]+$/, "영문 소문자/숫자/언더스코어/점만 사용 가능합니다.");

const SystemSettingSchema = z.object({
  key: KeySchema,
  value: z.string().min(1, "설정값을 입력해주세요."),
  description: z.string().optional().nullable(),
});

// ── 생성 ──
export async function createSystemSetting(
  _prevState: SystemSettingFormState,
  formData: FormData
): Promise<SystemSettingFormState> {
  const session = await verifyAdminSession();
  if (!canWriteSystemSettings(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다.(시스템 설정은 super_admin만 편집 가능)" };
  }

  const descRaw = formData.get("description");
  const parsed = SystemSettingSchema.safeParse({
    key: formData.get("key"),
    value: formData.get("value"),
    description: descRaw === "" ? null : descRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.systemSetting.findUnique({ where: { key: parsed.data.key } });
  if (existing) {
    return { error: "이미 동일한 key의 설정이 존재합니다." };
  }

  const valueJson = normalizeValueToJson(parsed.data.value);

  const created = await prisma.systemSetting.create({
    data: {
      key: parsed.data.key,
      value: valueJson,
      description: parsed.data.description,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "system_setting",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ key: created.key, value: created.value }),
    },
  });

  revalidatePath("/system-settings");
  return { success: true };
}

// ── 수정 ──
const UpdateSystemSettingSchema = z.object({
  id: z.coerce.number().int().positive(),
  value: z.string().min(1, "설정값을 입력해주세요."),
  description: z.string().optional().nullable(),
});

export async function updateSystemSetting(
  _prevState: SystemSettingFormState,
  formData: FormData
): Promise<SystemSettingFormState> {
  const session = await verifyAdminSession();
  if (!canWriteSystemSettings(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다.(시스템 설정은 super_admin만 편집 가능)" };
  }

  const descRaw = formData.get("description");
  const parsed = UpdateSystemSettingSchema.safeParse({
    id: formData.get("id"),
    value: formData.get("value"),
    description: descRaw === "" ? null : descRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.systemSetting.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 설정입니다." };
  }

  const valueJson = normalizeValueToJson(parsed.data.value);

  const after = await prisma.systemSetting.update({
    where: { id: parsed.data.id },
    data: {
      value: valueJson,
      description: parsed.data.description,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "system_setting",
      targetId: parsed.data.id,
      before: JSON.stringify({ value: before.value, description: before.description }),
      after: JSON.stringify({ value: after.value, description: after.description }),
    },
  });

  revalidatePath("/system-settings");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteSystemSettingSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteSystemSetting(
  _prevState: SystemSettingFormState,
  formData: FormData
): Promise<SystemSettingFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteSystemSettings(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteSystemSettingSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.systemSetting.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 설정입니다." };
  }

  await prisma.systemSetting.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "system_setting",
      targetId: parsed.data.id,
      before: JSON.stringify({ key: before.key, value: before.value }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/system-settings");
  return { success: true };
}
