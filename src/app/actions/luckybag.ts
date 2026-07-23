"use server";

// 상점 관리 — 복주머니 관리 Server Actions
// 05_Admin_System_Design.md §3.4 "상점 관리" — 04A I-1 luckybag_products, I-2 luckybag_grades,
// I-3 luckybag_reward_pools, I-4 luckybag_seasons.
// [스코프 결정] 이번 소단위는 상품/등급/시즌/보상풀(확률테이블) CRUD까지 다룬다.
//   luckybag_open_logs(I-5, 회원 활동 결과 데이터)는 조회 전용 화면으로 다음 소단위에서 추가한다
//   (amulet_items 1단계 -> user_amulets 2단계와 동일한 분할 방식).
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
// 04A I-3 명시: probability는 그룹(동일 luckybag_product_id) 합계가 100이 되어야 함(애플리케이션 검증).
//   실제 운영에서는 여러 차례에 걸쳐 보상 항목을 추가/수정하므로, 매 작업마다 합계가 정확히 100이 되도록
//   강제하면 편집이 불가능해진다. 따라서 "합계가 100을 초과하는 것"은 즉시 차단하고, 상품 목록/보상풀
//   목록 화면에서는 현재 합계를 항상 노출하여 관리자가 100%를 맞췄는지 확인할 수 있도록 한다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteShop(roleCode: string): boolean {
  return canWriteMenu(roleCode, "shop");
}

function canDeleteShop(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "shop");
}

export interface LuckybagFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/shop/luckybag";

// ══════════════════════════════════════════════════════════
// 04A I-2 luckybag_grades (마스터)
// ══════════════════════════════════════════════════════════
const LuckybagGradeSchema = z.object({
  code: z.string().min(1, "등급 코드를 입력해주세요."),
  name: z.string().min(1, "등급명을 입력해주세요."),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
});

export async function createLuckybagGrade(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = LuckybagGradeSchema.safeParse({
    code: formData.get("code"),
    name: formData.get("name"),
    sortOrder: formData.get("sortOrder"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.luckybagGrade.findUnique({ where: { code: parsed.data.code } });
  if (existing) {
    return { error: "이미 동일한 등급 코드가 존재합니다." };
  }

  const created = await prisma.luckybagGrade.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "luckybag_grade",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateLuckybagGradeSchema = LuckybagGradeSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateLuckybagGrade(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateLuckybagGradeSchema.safeParse({
    id: formData.get("id"),
    code: formData.get("code"),
    name: formData.get("name"),
    sortOrder: formData.get("sortOrder"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;
  const before = await prisma.luckybagGrade.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 등급입니다." };
  }

  const after = await prisma.luckybagGrade.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "luckybag_grade",
      targetId: id,
      before: JSON.stringify({ code: before.code, name: before.name }),
      after: JSON.stringify({ code: after.code, name: after.name }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A I-4 luckybag_seasons
// ══════════════════════════════════════════════════════════
const LuckybagSeasonSchema = z.object({
  name: z.string().min(1, "시즌명을 입력해주세요."),
  startAt: z.string().min(1, "시작일을 입력해주세요."),
  endAt: z.string().min(1, "종료일을 입력해주세요."),
});

export async function createLuckybagSeason(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = LuckybagSeasonSchema.safeParse({
    name: formData.get("name"),
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const startAt = new Date(parsed.data.startAt);
  const endAt = new Date(parsed.data.endAt);
  if (Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime())) {
    return { error: "날짜 형식이 올바르지 않습니다." };
  }
  if (endAt <= startAt) {
    return { error: "종료일은 시작일보다 이후여야 합니다." };
  }

  const created = await prisma.luckybagSeason.create({
    data: {
      name: parsed.data.name,
      startAt,
      endAt,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "luckybag_season",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name: created.name }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateLuckybagSeasonSchema = LuckybagSeasonSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateLuckybagSeason(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateLuckybagSeasonSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const startAt = new Date(parsed.data.startAt);
  const endAt = new Date(parsed.data.endAt);
  if (Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime())) {
    return { error: "날짜 형식이 올바르지 않습니다." };
  }
  if (endAt <= startAt) {
    return { error: "종료일은 시작일보다 이후여야 합니다." };
  }

  const before = await prisma.luckybagSeason.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 시즌입니다." };
  }

  const after = await prisma.luckybagSeason.update({
    where: { id: parsed.data.id },
    data: { name: parsed.data.name, startAt, endAt, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "luckybag_season",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ name: after.name }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteLuckybagSeasonSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteLuckybagSeason(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteLuckybagSeasonSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckybagSeason.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 시즌입니다." };
  }

  await prisma.luckybagSeason.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "luckybag_season",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A I-1 luckybag_products
// ══════════════════════════════════════════════════════════
const LuckybagProductSchema = z.object({
  name: z.string().min(1, "상품명을 입력해주세요."),
  pricePoint: z.coerce.number().int().min(0).optional().default(0),
  imageUrl: z.string().optional().nullable(),
  seasonId: z.coerce.number().int().positive().optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
});

export async function createLuckybagProduct(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const seasonIdRaw = formData.get("seasonId");
  const parsed = LuckybagProductSchema.safeParse({
    name: formData.get("name"),
    pricePoint: formData.get("pricePoint"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    seasonId: seasonIdRaw === "" ? null : seasonIdRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  if (parsed.data.seasonId) {
    const season = await prisma.luckybagSeason.findUnique({ where: { id: parsed.data.seasonId } });
    if (!season) {
      return { error: "존재하지 않는 시즌입니다." };
    }
  }

  const created = await prisma.luckybagProduct.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "luckybag_product",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ name: created.name, pricePoint: created.pricePoint }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateLuckybagProductSchema = LuckybagProductSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateLuckybagProduct(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const seasonIdRaw = formData.get("seasonId");
  const parsed = UpdateLuckybagProductSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    pricePoint: formData.get("pricePoint"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    seasonId: seasonIdRaw === "" ? null : seasonIdRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  if (data.seasonId) {
    const season = await prisma.luckybagSeason.findUnique({ where: { id: data.seasonId } });
    if (!season) {
      return { error: "존재하지 않는 시즌입니다." };
    }
  }

  const before = await prisma.luckybagProduct.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 복주머니 상품입니다." };
  }

  const after = await prisma.luckybagProduct.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "luckybag_product",
      targetId: id,
      before: JSON.stringify({ name: before.name, pricePoint: before.pricePoint }),
      after: JSON.stringify({ name: after.name, pricePoint: after.pricePoint }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteLuckybagProductSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteLuckybagProduct(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteLuckybagProductSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckybagProduct.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 복주머니 상품입니다." };
  }

  await prisma.luckybagProduct.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "luckybag_product",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A I-3 luckybag_reward_pools (확률테이블) — 합 100% 검증 로직 필수
// ══════════════════════════════════════════════════════════
const LuckybagRewardPoolSchema = z.object({
  luckybagProductId: z.coerce.number().int().positive("복주머니 상품을 선택해주세요."),
  gradeId: z.coerce.number().int().positive("등급을 선택해주세요."),
  rewardType: z.enum(["point", "amulet", "giftcard_fragment", "none"]),
  rewardRefId: z.coerce.number().int().positive().optional().nullable(),
  rewardAmount: z.coerce.number().int().min(0).optional().nullable(),
  probability: z.coerce
    .number()
    .gt(0, "확률은 0보다 커야 합니다.")
    .lte(100, "확률은 100 이하여야 합니다."),
});

/** 지정 상품의 활성 보상풀 확률 합계를 계산한다. excludeId를 지정하면 해당 레코드는 합산에서 제외한다. */
async function calcRewardPoolProbabilitySum(
  luckybagProductId: number,
  excludeId?: number
): Promise<number> {
  const pools = await prisma.luckybagRewardPool.findMany({
    where: { luckybagProductId, deletedAt: null, ...(excludeId ? { id: { not: excludeId } } : {}) },
  });
  return pools.reduce((acc, p) => acc + p.probability, 0);
}

export async function createLuckybagRewardPool(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardRefIdRaw = formData.get("rewardRefId");
  const rewardAmountRaw = formData.get("rewardAmount");
  const parsed = LuckybagRewardPoolSchema.safeParse({
    luckybagProductId: formData.get("luckybagProductId"),
    gradeId: formData.get("gradeId"),
    rewardType: formData.get("rewardType"),
    rewardRefId: rewardRefIdRaw === "" ? null : rewardRefIdRaw,
    rewardAmount: rewardAmountRaw === "" ? null : rewardAmountRaw,
    probability: formData.get("probability"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const product = await prisma.luckybagProduct.findUnique({
    where: { id: parsed.data.luckybagProductId },
  });
  if (!product) {
    return { error: "존재하지 않는 복주머니 상품입니다." };
  }
  const grade = await prisma.luckybagGrade.findUnique({ where: { id: parsed.data.gradeId } });
  if (!grade) {
    return { error: "존재하지 않는 등급입니다." };
  }

  // 04A I-3: 그룹(luckybag_product_id) 합계가 100을 초과하면 즉시 차단.
  const currentSum = await calcRewardPoolProbabilitySum(parsed.data.luckybagProductId);
  const newSum = currentSum + parsed.data.probability;
  if (newSum > 100.0001) {
    return {
      error: `확률 합계가 100%를 초과합니다. (현재 합계 ${currentSum}% + 신규 ${parsed.data.probability}% = ${newSum}%)`,
    };
  }

  const created = await prisma.luckybagRewardPool.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "luckybag_reward_pool",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateLuckybagRewardPoolSchema = LuckybagRewardPoolSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateLuckybagRewardPool(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardRefIdRaw = formData.get("rewardRefId");
  const rewardAmountRaw = formData.get("rewardAmount");
  const parsed = UpdateLuckybagRewardPoolSchema.safeParse({
    id: formData.get("id"),
    luckybagProductId: formData.get("luckybagProductId"),
    gradeId: formData.get("gradeId"),
    rewardType: formData.get("rewardType"),
    rewardRefId: rewardRefIdRaw === "" ? null : rewardRefIdRaw,
    rewardAmount: rewardAmountRaw === "" ? null : rewardAmountRaw,
    probability: formData.get("probability"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;
  const before = await prisma.luckybagRewardPool.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 보상 항목입니다." };
  }

  const currentSum = await calcRewardPoolProbabilitySum(data.luckybagProductId, id);
  const newSum = currentSum + data.probability;
  if (newSum > 100.0001) {
    return {
      error: `확률 합계가 100%를 초과합니다. (다른 항목 합계 ${currentSum}% + 수정값 ${data.probability}% = ${newSum}%)`,
    };
  }

  const after = await prisma.luckybagRewardPool.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "luckybag_reward_pool",
      targetId: id,
      before: JSON.stringify({ probability: before.probability, rewardType: before.rewardType }),
      after: JSON.stringify({ probability: after.probability, rewardType: after.rewardType }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteLuckybagRewardPoolSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteLuckybagRewardPool(
  _prevState: LuckybagFormState,
  formData: FormData
): Promise<LuckybagFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteLuckybagRewardPoolSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckybagRewardPool.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 보상 항목입니다." };
  }

  await prisma.luckybagRewardPool.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "luckybag_reward_pool",
      targetId: parsed.data.id,
      before: JSON.stringify({ probability: before.probability }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
