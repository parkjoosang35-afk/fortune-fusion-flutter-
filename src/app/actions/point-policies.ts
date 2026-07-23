"use server";

// 포인트 정책 관리 Server Actions
// 05_Admin_System_Design.md §3.3 "포인트 정책 설정" — 04A C-3 point_policies CRUD
// [설계 결정] "무료/유료 정책 설정"(Phase18-2 보류) 통합:
//   source_type이 earn류(attendance/mission/event/community)면 "적립형" 정책,
//   spend류(ai_*_request 등)면 "차감형(무료횟수/초과시차감)" 정책으로 UI에서 라벨만 구분.
//   04A C-3 스펙(source_type/amount/daily_limit/is_active)을 그대로 사용(신규 컬럼 없음).
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}

function canDeleteReward(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "reward");
}

const PointPolicySchema = z.object({
  sourceType: z
    .string()
    .min(1, "source_type을 입력해주세요.")
    .regex(/^[a-z0-9_]+$/, "영문 소문자/숫자/언더스코어만 사용 가능합니다."),
  amount: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
  dailyLimit: z.coerce.number().int().min(0).optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface PointPolicyFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createPointPolicy(
  _prevState: PointPolicyFormState,
  formData: FormData
): Promise<PointPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const parsed = PointPolicySchema.safeParse({
    sourceType: formData.get("sourceType"),
    amount: formData.get("amount"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.pointPolicy.findUnique({
    where: { sourceType: parsed.data.sourceType },
  });
  if (existing) {
    return { error: "이미 동일한 source_type의 정책이 존재합니다." };
  }

  const created = await prisma.pointPolicy.create({
    data: {
      ...parsed.data,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "point_policy",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/policies");
  return { success: true };
}

// ── 수정 ──
const UpdatePointPolicySchema = PointPolicySchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updatePointPolicy(
  _prevState: PointPolicyFormState,
  formData: FormData
): Promise<PointPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const parsed = UpdatePointPolicySchema.safeParse({
    id: formData.get("id"),
    sourceType: formData.get("sourceType"),
    amount: formData.get("amount"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.pointPolicy.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  // source_type 변경 시 중복 체크
  if (data.sourceType !== before.sourceType) {
    const dup = await prisma.pointPolicy.findUnique({ where: { sourceType: data.sourceType } });
    if (dup) {
      return { error: "이미 동일한 source_type의 정책이 존재합니다." };
    }
  }

  const after = await prisma.pointPolicy.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "point_policy",
      targetId: id,
      before: JSON.stringify({
        sourceType: before.sourceType,
        amount: before.amount,
        dailyLimit: before.dailyLimit,
        isActive: before.isActive,
      }),
      after: JSON.stringify({
        sourceType: after.sourceType,
        amount: after.amount,
        dailyLimit: after.dailyLimit,
        isActive: after.isActive,
      }),
    },
  });

  revalidatePath("/reward/policies");
  return { success: true };
}

// ── 삭제 (soft delete) — RBAC상 reward는 operator까지 RW, D는 super_admin 전용 ──
const DeletePointPolicySchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function deletePointPolicy(
  _prevState: PointPolicyFormState,
  formData: FormData
): Promise<PointPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeletePointPolicySchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.pointPolicy.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  await prisma.pointPolicy.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "point_policy",
      targetId: parsed.data.id,
      before: JSON.stringify({ sourceType: before.sourceType }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/policies");
  return { success: true };
}
