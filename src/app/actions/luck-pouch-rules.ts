"use server";

// 복주머니(커뮤니티 활동 포인트) 적립/소비/구매 규칙 관리 Server Actions
// [열림패스/행복머니/복주머니 통합정책] pass-policies.ts와 동일한 컨벤션.
// RBAC menuCode는 "reward"를 재사용한다.
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

const RULE_TYPES = ["earn", "spend", "purchase"] as const;

const LuckPouchRuleSchema = z.object({
  name: z.string().min(1, "규칙명을 입력해주세요."),
  ruleType: z.enum(RULE_TYPES, { message: "ruleType은 earn/spend/purchase 중 하나여야 합니다." }),
  actionType: z.string().min(1, "actionType을 입력해주세요."),
  targetScope: z.string().optional().nullable(),
  amount: z.coerce.number().int().positive("수량은 1 이상이어야 합니다."),
  cashPrice: z.coerce.number().int().positive().optional().nullable(),
  dailyLimit: z.coerce.number().int().min(0).optional().nullable(),
  isPurchasable: z.coerce.boolean().optional().default(false),
  isManualGrantable: z.coerce.boolean().optional().default(true),
  displayPriority: z.coerce.number().int().optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface LuckPouchRuleFormState {
  error?: string;
  success?: boolean;
}

function boolField(formData: FormData, key: string): boolean {
  return formData.get(key) === "on" || formData.get(key) === "true";
}

function nullableText(formData: FormData, key: string): string | null {
  const v = formData.get(key);
  return v === "" || v == null ? null : String(v);
}

// ── 생성 ──
export async function createLuckPouchRule(
  _prevState: LuckPouchRuleFormState,
  formData: FormData
): Promise<LuckPouchRuleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const cashPriceRaw = formData.get("cashPrice");
  const parsed = LuckPouchRuleSchema.safeParse({
    name: formData.get("name"),
    ruleType: formData.get("ruleType"),
    actionType: formData.get("actionType"),
    targetScope: nullableText(formData, "targetScope"),
    amount: formData.get("amount"),
    cashPrice: cashPriceRaw === "" ? null : cashPriceRaw,
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    isPurchasable: boolField(formData, "isPurchasable"),
    isManualGrantable: boolField(formData, "isManualGrantable"),
    displayPriority: formData.get("displayPriority") ?? 0,
    isActive: boolField(formData, "isActive"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.luckPouchRule.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "luck_pouch_rule",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/luck-pouch-rules");
  return { success: true };
}

// ── 수정 ──
const UpdateLuckPouchRuleSchema = LuckPouchRuleSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateLuckPouchRule(
  _prevState: LuckPouchRuleFormState,
  formData: FormData
): Promise<LuckPouchRuleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dailyLimitRaw = formData.get("dailyLimit");
  const cashPriceRaw = formData.get("cashPrice");
  const parsed = UpdateLuckPouchRuleSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    ruleType: formData.get("ruleType"),
    actionType: formData.get("actionType"),
    targetScope: nullableText(formData, "targetScope"),
    amount: formData.get("amount"),
    cashPrice: cashPriceRaw === "" ? null : cashPriceRaw,
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    isPurchasable: boolField(formData, "isPurchasable"),
    isManualGrantable: boolField(formData, "isManualGrantable"),
    displayPriority: formData.get("displayPriority") ?? 0,
    isActive: boolField(formData, "isActive"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.luckPouchRule.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 규칙입니다." };
  }

  const after = await prisma.luckPouchRule.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "luck_pouch_rule",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidatePath("/reward/luck-pouch-rules");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteLuckPouchRuleSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteLuckPouchRule(
  _prevState: LuckPouchRuleFormState,
  formData: FormData
): Promise<LuckPouchRuleFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteLuckPouchRuleSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckPouchRule.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 규칙입니다." };
  }

  await prisma.luckPouchRule.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "luck_pouch_rule",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/luck-pouch-rules");
  return { success: true };
}
