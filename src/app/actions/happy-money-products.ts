"use server";

// 행복머니(유료 충전 포인트) 상품 관리 Server Actions
// [열림패스/행복머니/복주머니 통합정책] pass-policies.ts와 완전히 동일한 컨벤션으로 구성.
// RBAC menuCode는 "reward"(리워드관리)를 재사용한다.
// 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
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

const HappyMoneyProductSchema = z.object({
  name: z.string().min(1, "상품명을 입력해주세요."),
  cashPrice: z.coerce.number().int().positive("현금 가격은 1 이상이어야 합니다."),
  happyMoneyAmount: z.coerce.number().int().positive("지급 행복머니는 1 이상이어야 합니다."),
  bonusAmount: z.coerce.number().int().min(0).optional().default(0),
  allowedUsageScopes: z.string().optional().default("pass,subscription,gift"),
  isEventGrantable: z.coerce.boolean().optional().default(true),
  isManualGrantable: z.coerce.boolean().optional().default(true),
  isFeatured: z.coerce.boolean().optional().default(false),
  displayPriority: z.coerce.number().int().optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface HappyMoneyProductFormState {
  error?: string;
  success?: boolean;
}

function boolField(formData: FormData, key: string): boolean {
  return formData.get(key) === "on" || formData.get(key) === "true";
}

// ── 생성 ──
export async function createHappyMoneyProduct(
  _prevState: HappyMoneyProductFormState,
  formData: FormData
): Promise<HappyMoneyProductFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = HappyMoneyProductSchema.safeParse({
    name: formData.get("name"),
    cashPrice: formData.get("cashPrice"),
    happyMoneyAmount: formData.get("happyMoneyAmount"),
    bonusAmount: formData.get("bonusAmount") ?? 0,
    allowedUsageScopes: formData.get("allowedUsageScopes") || "pass,subscription,gift",
    isEventGrantable: boolField(formData, "isEventGrantable"),
    isManualGrantable: boolField(formData, "isManualGrantable"),
    isFeatured: boolField(formData, "isFeatured"),
    displayPriority: formData.get("displayPriority") ?? 0,
    isActive: boolField(formData, "isActive"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.happyMoneyProduct.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "happy_money_product",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/happy-money-products");
  return { success: true };
}

// ── 수정 ──
const UpdateHappyMoneyProductSchema = HappyMoneyProductSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateHappyMoneyProduct(
  _prevState: HappyMoneyProductFormState,
  formData: FormData
): Promise<HappyMoneyProductFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateHappyMoneyProductSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    cashPrice: formData.get("cashPrice"),
    happyMoneyAmount: formData.get("happyMoneyAmount"),
    bonusAmount: formData.get("bonusAmount") ?? 0,
    allowedUsageScopes: formData.get("allowedUsageScopes") || "pass,subscription,gift",
    isEventGrantable: boolField(formData, "isEventGrantable"),
    isManualGrantable: boolField(formData, "isManualGrantable"),
    isFeatured: boolField(formData, "isFeatured"),
    displayPriority: formData.get("displayPriority") ?? 0,
    isActive: boolField(formData, "isActive"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.happyMoneyProduct.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 상품입니다." };
  }

  const after = await prisma.happyMoneyProduct.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "happy_money_product",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidatePath("/reward/happy-money-products");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteHappyMoneyProductSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteHappyMoneyProduct(
  _prevState: HappyMoneyProductFormState,
  formData: FormData
): Promise<HappyMoneyProductFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteHappyMoneyProductSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.happyMoneyProduct.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 상품입니다." };
  }

  await prisma.happyMoneyProduct.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "happy_money_product",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/happy-money-products");
  return { success: true };
}
