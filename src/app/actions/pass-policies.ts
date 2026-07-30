"use server";

// 알림패스(AlarmPass) 정책 관리 Server Actions
// [문서7/문서8 승인 반영] Fortune Fusion 3대 재화 중 ①알림패스(시간제 콘텐츠 열람권)의
// 관리자 CRUD. point-policies.ts(key-value형 point_policies) 패턴을 그대로 복제하되,
// pass_policies는 완전 CRUD 대상 테이블이므로 sourceType unique 대신 일반 id 기반 CRUD로 구성.
// RBAC menuCode는 "reward"(리워드관리)를 재사용한다(신규 메뉴 미도입, 문서6 결정 반영).
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

const PASS_TYPES = ["ad", "partner", "subscription", "event"] as const;

const PassPolicySchema = z.object({
  name: z.string().min(1, "정책명을 입력해주세요."),
  passType: z.enum(PASS_TYPES, {
    message: "passType은 ad/partner/subscription/event 중 하나여야 합니다.",
  }),
  durationMin: z.coerce.number().int().positive("지속시간(분)은 1 이상이어야 합니다."),
  dailyLimit: z.coerce.number().int().min(0).optional().nullable(),
  ctaText: z.string().optional().nullable(),
  bannerImageUrl: z.string().optional().nullable(),
  linkUrl: z.string().optional().nullable(),
  bonusPoint: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface PassPolicyFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createPassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const parsed = PassPolicySchema.safeParse({
    name: formData.get("name"),
    passType: formData.get("passType"),
    durationMin: formData.get("durationMin"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    ctaText: formData.get("ctaText") || null,
    bannerImageUrl: formData.get("bannerImageUrl") || null,
    linkUrl: formData.get("linkUrl") || null,
    bonusPoint: formData.get("bonusPoint") ?? 0,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.passPolicy.create({
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
      targetType: "pass_policy",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}

// ── 수정 ──
const UpdatePassPolicySchema = PassPolicySchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updatePassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const parsed = UpdatePassPolicySchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    passType: formData.get("passType"),
    durationMin: formData.get("durationMin"),
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    ctaText: formData.get("ctaText") || null,
    bannerImageUrl: formData.get("bannerImageUrl") || null,
    linkUrl: formData.get("linkUrl") || null,
    bonusPoint: formData.get("bonusPoint") ?? 0,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.passPolicy.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  const after = await prisma.passPolicy.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "pass_policy",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        passType: before.passType,
        durationMin: before.durationMin,
        dailyLimit: before.dailyLimit,
        bonusPoint: before.bonusPoint,
        isActive: before.isActive,
      }),
      after: JSON.stringify({
        name: after.name,
        passType: after.passType,
        durationMin: after.durationMin,
        dailyLimit: after.dailyLimit,
        bonusPoint: after.bonusPoint,
        isActive: after.isActive,
      }),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}

// ── 삭제 (soft delete) — RBAC상 reward는 operator까지 RW, D는 super_admin 전용 ──
const DeletePassPolicySchema = z.object({
  id: z.coerce.number().int().positive(),
});

export async function deletePassPolicy(
  _prevState: PassPolicyFormState,
  formData: FormData
): Promise<PassPolicyFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeletePassPolicySchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.passPolicy.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 정책입니다." };
  }

  await prisma.passPolicy.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "pass_policy",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/pass-policies");
  return { success: true };
}
