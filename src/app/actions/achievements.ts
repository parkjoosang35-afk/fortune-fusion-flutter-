"use server";

// 업적 관리 Server Actions
// 05_Admin_System_Design.md §3.3 "업적관리" — 04A D-5 achievements CRUD
// 참고: user_achievements(D-6, 회원 달성 결과) 테이블은 회원 활동 결과 데이터이므로
//       관리자 화면에서는 조회 전용으로만 노출하며, 이 파일은 업적(achievement) 마스터만 다룬다.
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

const AchievementSchema = z.object({
  code: z
    .string()
    .min(1, "code를 입력해주세요.")
    .regex(/^[a-z0-9_]+$/, "영문 소문자/숫자/언더스코어만 사용 가능합니다."),
  title: z.string().min(1, "제목을 입력해주세요."),
  conditionType: z.string().min(1, "condition_type을 입력해주세요."),
  conditionValue: z.string().min(1, "condition_value(JSON)를 입력해주세요."),
  rewardPoint: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
  badgeImageFileId: z.coerce.number().int().optional().nullable(),
});

export interface AchievementFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createAchievement(
  _prevState: AchievementFormState,
  formData: FormData
): Promise<AchievementFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const badgeIdRaw = formData.get("badgeImageFileId");
  const parsed = AchievementSchema.safeParse({
    code: formData.get("code"),
    title: formData.get("title"),
    conditionType: formData.get("conditionType"),
    conditionValue: formData.get("conditionValue"),
    rewardPoint: formData.get("rewardPoint"),
    badgeImageFileId: badgeIdRaw === "" ? null : badgeIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  try {
    JSON.parse(parsed.data.conditionValue);
  } catch {
    return { error: "condition_value는 유효한 JSON 문자열이어야 합니다." };
  }

  const existing = await prisma.achievement.findUnique({ where: { code: parsed.data.code } });
  if (existing) {
    return { error: "이미 동일한 code의 업적이 존재합니다." };
  }

  const created = await prisma.achievement.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "achievement",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/achievements");
  return { success: true };
}

// ── 수정 ──
const UpdateAchievementSchema = AchievementSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateAchievement(
  _prevState: AchievementFormState,
  formData: FormData
): Promise<AchievementFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const badgeIdRaw = formData.get("badgeImageFileId");
  const parsed = UpdateAchievementSchema.safeParse({
    id: formData.get("id"),
    code: formData.get("code"),
    title: formData.get("title"),
    conditionType: formData.get("conditionType"),
    conditionValue: formData.get("conditionValue"),
    rewardPoint: formData.get("rewardPoint"),
    badgeImageFileId: badgeIdRaw === "" ? null : badgeIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  try {
    JSON.parse(parsed.data.conditionValue);
  } catch {
    return { error: "condition_value는 유효한 JSON 문자열이어야 합니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.achievement.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 업적입니다." };
  }

  if (data.code !== before.code) {
    const dup = await prisma.achievement.findUnique({ where: { code: data.code } });
    if (dup) {
      return { error: "이미 동일한 code의 업적이 존재합니다." };
    }
  }

  const after = await prisma.achievement.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "achievement",
      targetId: id,
      before: JSON.stringify({
        code: before.code,
        title: before.title,
        conditionType: before.conditionType,
        rewardPoint: before.rewardPoint,
      }),
      after: JSON.stringify({
        code: after.code,
        title: after.title,
        conditionType: after.conditionType,
        rewardPoint: after.rewardPoint,
      }),
    },
  });

  revalidatePath("/reward/achievements");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteAchievementSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteAchievement(
  _prevState: AchievementFormState,
  formData: FormData
): Promise<AchievementFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteAchievementSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.achievement.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 업적입니다." };
  }

  await prisma.achievement.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "achievement",
      targetId: parsed.data.id,
      before: JSON.stringify({ code: before.code }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/achievements");
  return { success: true };
}
