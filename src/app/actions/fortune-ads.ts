"use server";

// [신통방통 복주머니 광고 적립 시스템] 관리자 광고(FortuneAd) CRUD Server Actions.
// open-pass-ad-sources.ts의 검증된 패턴(zod schema + verifyAdminSession +
// canWriteMenu/canDeleteMenu + operationLog + revalidatePath + soft-delete)을
// 그대로 재사용한다. 기존 열림패스 광고소스와는 별개의 독립 엔티티이며,
// 지급 시 UserPass가 아니라 Wallet(POINT)에 복주머니를 적립한다는 점만 다르다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

const AD_TYPES = ["image", "video", "external", "network"] as const;

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}
function canDeleteReward(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "reward");
}

function revalidateAll() {
  revalidatePath("/reward/fortune-ads");
  revalidatePath("/reward/fortune-ads/logs");
  revalidatePath("/reward/luck-pouch-rules");
}

const FortuneAdSchema = z.object({
  title: z.string().min(1, "광고명을 입력해주세요."),
  description: z.string().optional().nullable(),
  adType: z.enum(AD_TYPES, { message: "지원하지 않는 광고 유형입니다." }),
  imageUrl: z.string().optional().nullable(),
  videoUrl: z.string().optional().nullable(),
  externalUrl: z.string().optional().nullable(),
  adSourceHtml: z.string().optional().nullable(),
  rewardAmount: z.coerce.number().int().min(1, "1개 이상이어야 합니다.").default(10),
  watchSeconds: z.coerce.number().int().min(1, "1초 이상이어야 합니다.").default(15),
  isActive: z.coerce.boolean().optional().default(true),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
  priority: z.coerce.number().int().min(0).optional().default(0),
  perUserDailyLimit: z.coerce.number().int().min(1).optional().default(3),
  dailyLimitReward: z.coerce.number().int().min(0).optional().nullable(),
});

export interface FortuneAdFormState {
  error?: string;
  success?: boolean;
}

function readFortuneAdFormData(formData: FormData) {
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  const dailyLimitRewardRaw = formData.get("dailyLimitReward");
  return {
    title: formData.get("title"),
    description: formData.get("description") || null,
    adType: formData.get("adType"),
    imageUrl: formData.get("imageUrl") || null,
    videoUrl: formData.get("videoUrl") || null,
    externalUrl: formData.get("externalUrl") || null,
    adSourceHtml: formData.get("adSourceHtml") || null,
    rewardAmount: formData.get("rewardAmount") || 10,
    watchSeconds: formData.get("watchSeconds") || 15,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: startAtRaw || null,
    endAt: endAtRaw || null,
    priority: formData.get("priority") || 0,
    perUserDailyLimit: formData.get("perUserDailyLimit") || 3,
    dailyLimitReward: dailyLimitRewardRaw === "" ? null : dailyLimitRewardRaw,
  };
}

export async function createFortuneAd(
  _prevState: FortuneAdFormState,
  formData: FormData
): Promise<FortuneAdFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = FortuneAdSchema.safeParse(readFortuneAdFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  const created = await prisma.fortuneAd.create({
    data: {
      title: data.title,
      description: data.description,
      adType: data.adType,
      imageUrl: data.imageUrl,
      videoUrl: data.videoUrl,
      externalUrl: data.externalUrl,
      adSourceHtml: data.adSourceHtml,
      rewardAmount: data.rewardAmount,
      watchSeconds: data.watchSeconds,
      isActive: data.isActive,
      startAt: data.startAt ? new Date(data.startAt) : null,
      endAt: data.endAt ? new Date(data.endAt) : null,
      priority: data.priority,
      perUserDailyLimit: data.perUserDailyLimit,
      dailyLimitReward: data.dailyLimitReward,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "fortune_ad",
      targetId: created.id,
      after: JSON.stringify(created),
    },
  });

  revalidateAll();
  return { success: true };
}

export async function updateFortuneAd(
  _prevState: FortuneAdFormState,
  formData: FormData
): Promise<FortuneAdFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const id = Number(formData.get("id"));
  if (!id || Number.isNaN(id)) return { error: "잘못된 요청입니다." };

  const before = await prisma.fortuneAd.findUnique({ where: { id } });
  if (!before || before.deletedAt) return { error: "존재하지 않는 광고입니다." };

  const parsed = FortuneAdSchema.safeParse(readFortuneAdFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  const after = await prisma.fortuneAd.update({
    where: { id },
    data: {
      title: data.title,
      description: data.description,
      adType: data.adType,
      imageUrl: data.imageUrl,
      videoUrl: data.videoUrl,
      externalUrl: data.externalUrl,
      adSourceHtml: data.adSourceHtml,
      rewardAmount: data.rewardAmount,
      watchSeconds: data.watchSeconds,
      isActive: data.isActive,
      startAt: data.startAt ? new Date(data.startAt) : null,
      endAt: data.endAt ? new Date(data.endAt) : null,
      priority: data.priority,
      perUserDailyLimit: data.perUserDailyLimit,
      dailyLimitReward: data.dailyLimitReward,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "fortune_ad",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidateAll();
  return { success: true };
}

// [사용자 원칙: "관리자 ON/OFF 즉시반영"] 재배포 없이 노출여부를 즉시 토글하는 액션.
export async function toggleFortuneAdActive(id: number, isActive: boolean): Promise<FortuneAdFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }
  const before = await prisma.fortuneAd.findUnique({ where: { id } });
  if (!before) return { error: "존재하지 않는 광고입니다." };

  await prisma.fortuneAd.update({ where: { id }, data: { isActive, updatedBy: session.email } });
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: isActive ? "activate" : "deactivate",
      targetType: "fortune_ad",
      targetId: id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive }),
    },
  });
  revalidateAll();
  return { success: true };
}

export async function deleteFortuneAd(
  _prevState: FortuneAdFormState,
  formData: FormData
): Promise<FortuneAdFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const id = Number(formData.get("id"));
  if (!id || Number.isNaN(id)) return { error: "잘못된 요청입니다." };

  const before = await prisma.fortuneAd.findUnique({ where: { id } });
  if (!before || before.deletedAt) return { error: "존재하지 않는 광고입니다." };

  await prisma.fortuneAd.update({
    where: { id },
    data: { status: "deleted", isActive: false, deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "fortune_ad",
      targetId: id,
      before: JSON.stringify(before),
    },
  });

  revalidateAll();
  return { success: true };
}
