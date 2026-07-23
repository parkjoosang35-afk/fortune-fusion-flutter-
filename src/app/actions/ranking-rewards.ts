"use server";

// 랭킹 보상 설정 Server Actions
// 05_Admin_System_Design.md §3.3 "랭킹시즌관리" — 04A D-8 ranking_rewards CRUD
// 참고: ranking_snapshots(D-7, 랭킹 산출 결과) 테이블은 배치로 산출되는 회원 활동 결과
//       데이터이므로 관리자 화면에서는 조회 전용으로만 노출하며,
//       이 파일은 순위구간별 보상(ranking_reward) 설정만 다룬다.
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

const RankingRewardSchema = z
  .object({
    rankingType: z
      .string()
      .min(1, "ranking_type을 입력해주세요.")
      .regex(/^[a-z0-9_]+$/, "영문 소문자/숫자/언더스코어만 사용 가능합니다."),
    rankRangeMin: z.coerce.number().int().min(1, "1 이상의 값을 입력해주세요."),
    rankRangeMax: z.coerce.number().int().min(1, "1 이상의 값을 입력해주세요."),
    rewardPoint: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
    rewardItemType: z.string().optional().nullable(),
    rewardItemId: z.coerce.number().int().optional().nullable(),
  })
  .refine((v) => v.rankRangeMax >= v.rankRangeMin, {
    message: "최대 순위는 최소 순위보다 크거나 같아야 합니다.",
    path: ["rankRangeMax"],
  });

export interface RankingRewardFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createRankingReward(
  _prevState: RankingRewardFormState,
  formData: FormData
): Promise<RankingRewardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardItemTypeRaw = formData.get("rewardItemType");
  const rewardItemIdRaw = formData.get("rewardItemId");
  const parsed = RankingRewardSchema.safeParse({
    rankingType: formData.get("rankingType"),
    rankRangeMin: formData.get("rankRangeMin"),
    rankRangeMax: formData.get("rankRangeMax"),
    rewardPoint: formData.get("rewardPoint"),
    rewardItemType: rewardItemTypeRaw === "" ? null : rewardItemTypeRaw,
    rewardItemId: rewardItemIdRaw === "" ? null : rewardItemIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.rankingReward.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "ranking_reward",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/ranking");
  return { success: true };
}

// ── 수정 ──
const UpdateRankingRewardSchema = z
  .object({
    id: z.coerce.number().int().positive(),
    rankingType: z
      .string()
      .min(1, "ranking_type을 입력해주세요.")
      .regex(/^[a-z0-9_]+$/, "영문 소문자/숫자/언더스코어만 사용 가능합니다."),
    rankRangeMin: z.coerce.number().int().min(1, "1 이상의 값을 입력해주세요."),
    rankRangeMax: z.coerce.number().int().min(1, "1 이상의 값을 입력해주세요."),
    rewardPoint: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
    rewardItemType: z.string().optional().nullable(),
    rewardItemId: z.coerce.number().int().optional().nullable(),
  })
  .refine((v) => v.rankRangeMax >= v.rankRangeMin, {
    message: "최대 순위는 최소 순위보다 크거나 같아야 합니다.",
    path: ["rankRangeMax"],
  });

export async function updateRankingReward(
  _prevState: RankingRewardFormState,
  formData: FormData
): Promise<RankingRewardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardItemTypeRaw = formData.get("rewardItemType");
  const rewardItemIdRaw = formData.get("rewardItemId");
  const parsed = UpdateRankingRewardSchema.safeParse({
    id: formData.get("id"),
    rankingType: formData.get("rankingType"),
    rankRangeMin: formData.get("rankRangeMin"),
    rankRangeMax: formData.get("rankRangeMax"),
    rewardPoint: formData.get("rewardPoint"),
    rewardItemType: rewardItemTypeRaw === "" ? null : rewardItemTypeRaw,
    rewardItemId: rewardItemIdRaw === "" ? null : rewardItemIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.rankingReward.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 랭킹 보상 설정입니다." };
  }

  const after = await prisma.rankingReward.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "ranking_reward",
      targetId: id,
      before: JSON.stringify({
        rankingType: before.rankingType,
        rankRangeMin: before.rankRangeMin,
        rankRangeMax: before.rankRangeMax,
        rewardPoint: before.rewardPoint,
      }),
      after: JSON.stringify({
        rankingType: after.rankingType,
        rankRangeMin: after.rankRangeMin,
        rankRangeMax: after.rankRangeMax,
        rewardPoint: after.rewardPoint,
      }),
    },
  });

  revalidatePath("/reward/ranking");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteRankingRewardSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteRankingReward(
  _prevState: RankingRewardFormState,
  formData: FormData
): Promise<RankingRewardFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteRankingRewardSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.rankingReward.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 랭킹 보상 설정입니다." };
  }

  await prisma.rankingReward.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "ranking_reward",
      targetId: parsed.data.id,
      before: JSON.stringify({ rankingType: before.rankingType }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/ranking");
  return { success: true };
}
