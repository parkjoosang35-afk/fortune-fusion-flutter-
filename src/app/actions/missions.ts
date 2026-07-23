"use server";

// 미션 관리 Server Actions
// 05_Admin_System_Design.md §3.3 "미션관리" — 04A D-3 missions CRUD
// 참고: user_missions(D-4, 회원 진행/완료 결과) 테이블은 회원 활동 결과 데이터이므로
//       관리자 화면에서는 조회 전용으로만 노출하며, 이 파일은 미션(mission) 마스터만 다룬다.
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

const MissionSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  actionType: z
    .string()
    .min(1, "action_type을 입력해주세요.")
    .regex(/^[a-z0-9_]+$/, "영문 소문자/숫자/언더스코어만 사용 가능합니다."),
  targetCount: z.coerce.number().int().min(1, "1 이상의 값을 입력해주세요."),
  rewardPoint: z.coerce.number().int().min(0, "0 이상의 값을 입력해주세요."),
  rewardItemType: z.string().optional().nullable(),
  rewardItemId: z.coerce.number().int().optional().nullable(),
  periodType: z.enum(["daily", "weekly", "achievement"]),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
});

export interface MissionFormState {
  error?: string;
  success?: boolean;
}

function toDate(v: string | null | undefined): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

// ── 생성 ──
export async function createMission(
  _prevState: MissionFormState,
  formData: FormData
): Promise<MissionFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardItemTypeRaw = formData.get("rewardItemType");
  const rewardItemIdRaw = formData.get("rewardItemId");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  const parsed = MissionSchema.safeParse({
    title: formData.get("title"),
    actionType: formData.get("actionType"),
    targetCount: formData.get("targetCount"),
    rewardPoint: formData.get("rewardPoint"),
    rewardItemType: rewardItemTypeRaw === "" ? null : rewardItemTypeRaw,
    rewardItemId: rewardItemIdRaw === "" ? null : rewardItemIdRaw,
    periodType: formData.get("periodType"),
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { startAt, endAt, ...rest } = parsed.data;

  const created = await prisma.mission.create({
    data: {
      ...rest,
      startAt: toDate(startAt),
      endAt: toDate(endAt),
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "mission",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}

// ── 수정 ──
const UpdateMissionSchema = MissionSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateMission(
  _prevState: MissionFormState,
  formData: FormData
): Promise<MissionFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const rewardItemTypeRaw = formData.get("rewardItemType");
  const rewardItemIdRaw = formData.get("rewardItemId");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  const parsed = UpdateMissionSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    actionType: formData.get("actionType"),
    targetCount: formData.get("targetCount"),
    rewardPoint: formData.get("rewardPoint"),
    rewardItemType: rewardItemTypeRaw === "" ? null : rewardItemTypeRaw,
    rewardItemId: rewardItemIdRaw === "" ? null : rewardItemIdRaw,
    periodType: formData.get("periodType"),
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, startAt, endAt, ...rest } = parsed.data;

  const before = await prisma.mission.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 미션입니다." };
  }

  const after = await prisma.mission.update({
    where: { id },
    data: {
      ...rest,
      startAt: toDate(startAt),
      endAt: toDate(endAt),
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "mission",
      targetId: id,
      before: JSON.stringify({
        title: before.title,
        actionType: before.actionType,
        targetCount: before.targetCount,
        rewardPoint: before.rewardPoint,
        periodType: before.periodType,
        isActive: before.isActive,
      }),
      after: JSON.stringify({
        title: after.title,
        actionType: after.actionType,
        targetCount: after.targetCount,
        rewardPoint: after.rewardPoint,
        periodType: after.periodType,
        isActive: after.isActive,
      }),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteMissionSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteMission(
  _prevState: MissionFormState,
  formData: FormData
): Promise<MissionFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteMissionSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.mission.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 미션입니다." };
  }

  await prisma.mission.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "mission",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/reward/missions");
  return { success: true };
}
