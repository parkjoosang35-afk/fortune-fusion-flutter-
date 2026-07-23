"use server";

// 출석보상규칙 관리 Server Actions
// 05_Admin_System_Design.md §3.3 "출석보상규칙설정" — 04A D-2 attendance_reward_rules CRUD
// 참고: attendances(D-1, 회원 출석 결과) 테이블은 회원 활동 결과 데이터이므로
//       관리자 화면에서는 조회 전용으로만 노출하며, 이 파일은 규칙(rule) 마스터만 다룬다.
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

const RuleSchema = z.object({
  streakDay: z.coerce.number().int().min(1, "1 이상의 연속 출석일수를 입력해주세요."),
  rewardPoint: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
  bonusItemType: z.string().optional().nullable(),
  bonusItemId: z.coerce.number().int().optional().nullable(),
});

export interface AttendanceRuleFormState {
  error?: string;
  success?: boolean;
}

// ── 생성 ──
export async function createAttendanceRule(
  _prevState: AttendanceRuleFormState,
  formData: FormData
): Promise<AttendanceRuleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const bonusItemTypeRaw = formData.get("bonusItemType");
  const bonusItemIdRaw = formData.get("bonusItemId");
  const parsed = RuleSchema.safeParse({
    streakDay: formData.get("streakDay"),
    rewardPoint: formData.get("rewardPoint"),
    bonusItemType: bonusItemTypeRaw === "" ? null : bonusItemTypeRaw,
    bonusItemId: bonusItemIdRaw === "" ? null : bonusItemIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const existing = await prisma.attendanceRewardRule.findUnique({
    where: { streakDay: parsed.data.streakDay },
  });
  if (existing) {
    return { error: "이미 동일한 연속 출석일수의 규칙이 존재합니다." };
  }

  const created = await prisma.attendanceRewardRule.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "attendance_reward_rule",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}

// ── 수정 ──
const UpdateRuleSchema = RuleSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateAttendanceRule(
  _prevState: AttendanceRuleFormState,
  formData: FormData
): Promise<AttendanceRuleFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const bonusItemTypeRaw = formData.get("bonusItemType");
  const bonusItemIdRaw = formData.get("bonusItemId");
  const parsed = UpdateRuleSchema.safeParse({
    id: formData.get("id"),
    streakDay: formData.get("streakDay"),
    rewardPoint: formData.get("rewardPoint"),
    bonusItemType: bonusItemTypeRaw === "" ? null : bonusItemTypeRaw,
    bonusItemId: bonusItemIdRaw === "" ? null : bonusItemIdRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;

  const before = await prisma.attendanceRewardRule.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 규칙입니다." };
  }

  if (data.streakDay !== before.streakDay) {
    const dup = await prisma.attendanceRewardRule.findUnique({ where: { streakDay: data.streakDay } });
    if (dup) {
      return { error: "이미 동일한 연속 출석일수의 규칙이 존재합니다." };
    }
  }

  const after = await prisma.attendanceRewardRule.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "attendance_reward_rule",
      targetId: id,
      before: JSON.stringify({
        streakDay: before.streakDay,
        rewardPoint: before.rewardPoint,
        bonusItemType: before.bonusItemType,
        bonusItemId: before.bonusItemId,
      }),
      after: JSON.stringify({
        streakDay: after.streakDay,
        rewardPoint: after.rewardPoint,
        bonusItemType: after.bonusItemType,
        bonusItemId: after.bonusItemId,
      }),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteRuleSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteAttendanceRule(
  _prevState: AttendanceRuleFormState,
  formData: FormData
): Promise<AttendanceRuleFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteRuleSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.attendanceRewardRule.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 규칙입니다." };
  }

  await prisma.attendanceRewardRule.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "attendance_reward_rule",
      targetId: parsed.data.id,
      before: JSON.stringify({ streakDay: before.streakDay }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}
