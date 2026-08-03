"use server";

// 열림패스 광고소스(리워드 광고 지급 채널) 관리 Server Actions
// [사용자 요청: 열림패스 관리자 광고소스 등록/연동] §4/§6-3/§8-3
// 광고소스는 상품과 독립된 재사용 가능 엔티티로 관리하고(§4 "중요" 항목),
// 나중에 여러 상품에 재사용 가능해야 한다 — 그래서 상품 바인딩은
// open-pass-bindings.ts에서 별도로 다룬다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";
// [주의] "use server" 파일은 async 함수만 export할 수 있어 상수 배열은 여기서 export하지 않는다.
import { AD_SOURCE_TYPES } from "@/lib/open-pass-constants";

function canWriteReward(roleCode: string): boolean {
  return canWriteMenu(roleCode, "reward");
}
function canDeleteReward(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "reward");
}

function revalidateAll() {
  revalidatePath("/reward/open-pass-ad-sources");
  revalidatePath("/reward/open-pass-bindings");
  revalidatePath("/reward/pass-policies");
  revalidatePath("/reward/test-lab");
}

const AdSourceSchema = z.object({
  sourceName: z.string().min(1, "광고소스명을 입력해주세요."),
  sourceType: z.enum(AD_SOURCE_TYPES, { message: "지원하지 않는 광고소스 유형입니다." }),
  networkName: z.string().optional().nullable(),
  adUnitId: z.string().optional().nullable(),
  placementId: z.string().optional().nullable(),
  rewardType: z.string().optional().nullable(),
  rewardValue: z.coerce.number().int().min(0).optional().nullable(),
  cooldownSeconds: z.coerce.number().int().min(0).optional().default(0),
  dailyLimit: z.coerce.number().int().min(0).optional().nullable(),
  failoverEnabled: z.coerce.boolean().optional().default(true),
  fallbackAttachmentId: z.coerce.number().int().positive().optional().nullable(),
  testModeEnabled: z.coerce.boolean().optional().default(false),
  isActive: z.coerce.boolean().optional().default(true),
  priority: z.coerce.number().int().min(0).optional().default(0),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
  // ── [프리패스 테스트 인프라 §4] mock_rewarded_* 전용 필드(실광고 소스는 둘 다 버려둔다) ──
  simulatedDurationSeconds: z.coerce.number().int().min(1).max(60).optional().nullable(),
  failMode: z.string().optional().nullable(),
});

export interface AdSourceFormState {
  error?: string;
  success?: boolean;
}

function readAdSourceFormData(formData: FormData) {
  const fallbackAttachmentIdRaw = formData.get("fallbackAttachmentId");
  const dailyLimitRaw = formData.get("dailyLimit");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  return {
    sourceName: formData.get("sourceName"),
    sourceType: formData.get("sourceType"),
    networkName: formData.get("networkName") || null,
    adUnitId: formData.get("adUnitId") || null,
    placementId: formData.get("placementId") || null,
    rewardType: formData.get("rewardType") || null,
    rewardValue: formData.get("rewardValue") || null,
    cooldownSeconds: formData.get("cooldownSeconds") || 0,
    dailyLimit: dailyLimitRaw === "" ? null : dailyLimitRaw,
    failoverEnabled: formData.get("failoverEnabled") === "on" || formData.get("failoverEnabled") === "true",
    fallbackAttachmentId: fallbackAttachmentIdRaw === "" ? null : fallbackAttachmentIdRaw,
    testModeEnabled: formData.get("testModeEnabled") === "on" || formData.get("testModeEnabled") === "true",
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    priority: formData.get("priority") || 0,
    startAt: startAtRaw || null,
    endAt: endAtRaw || null,
    simulatedDurationSeconds: formData.get("simulatedDurationSeconds") || null,
    failMode: formData.get("failMode") || null,
  };
}

export async function createOpenPassAdSource(
  _prevState: AdSourceFormState,
  formData: FormData
): Promise<AdSourceFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = AdSourceSchema.safeParse(readAdSourceFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  if (data.fallbackAttachmentId) {
    const attachment = await prisma.openPassAttachment.findUnique({ where: { id: data.fallbackAttachmentId } });
    if (!attachment || attachment.deletedAt) {
      return { error: "존재하지 않는 fallback 첨부파일입니다." };
    }
  }

  const created = await prisma.openPassAdSource.create({
    data: {
      sourceName: data.sourceName,
      sourceType: data.sourceType,
      networkName: data.networkName,
      adUnitId: data.adUnitId,
      placementId: data.placementId,
      rewardType: data.rewardType,
      rewardValue: data.rewardValue,
      cooldownSeconds: data.cooldownSeconds,
      dailyLimit: data.dailyLimit,
      failoverEnabled: data.failoverEnabled,
      fallbackAttachmentId: data.fallbackAttachmentId,
      testModeEnabled: data.testModeEnabled,
      isActive: data.isActive,
      priority: data.priority,
      startAt: data.startAt ? new Date(data.startAt) : null,
      endAt: data.endAt ? new Date(data.endAt) : null,
      simulatedDurationSeconds: data.simulatedDurationSeconds,
      failMode: data.failMode,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "open_pass_ad_source",
      targetId: created.id,
      after: JSON.stringify(created),
    },
  });

  revalidateAll();
  return { success: true };
}

export async function updateOpenPassAdSource(
  _prevState: AdSourceFormState,
  formData: FormData
): Promise<AdSourceFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const id = Number(formData.get("id"));
  if (!id || Number.isNaN(id)) return { error: "잘못된 요청입니다." };

  const before = await prisma.openPassAdSource.findUnique({ where: { id } });
  if (!before || before.deletedAt) return { error: "존재하지 않는 광고소스입니다." };

  const parsed = AdSourceSchema.safeParse(readAdSourceFormData(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const data = parsed.data;

  if (data.fallbackAttachmentId) {
    const attachment = await prisma.openPassAttachment.findUnique({ where: { id: data.fallbackAttachmentId } });
    if (!attachment || attachment.deletedAt) {
      return { error: "존재하지 않는 fallback 첨부파일입니다." };
    }
  }

  const after = await prisma.openPassAdSource.update({
    where: { id },
    data: {
      sourceName: data.sourceName,
      sourceType: data.sourceType,
      networkName: data.networkName,
      adUnitId: data.adUnitId,
      placementId: data.placementId,
      rewardType: data.rewardType,
      rewardValue: data.rewardValue,
      cooldownSeconds: data.cooldownSeconds,
      dailyLimit: data.dailyLimit,
      failoverEnabled: data.failoverEnabled,
      fallbackAttachmentId: data.fallbackAttachmentId,
      testModeEnabled: data.testModeEnabled,
      isActive: data.isActive,
      priority: data.priority,
      startAt: data.startAt ? new Date(data.startAt) : null,
      endAt: data.endAt ? new Date(data.endAt) : null,
      simulatedDurationSeconds: data.simulatedDurationSeconds,
      failMode: data.failMode,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "open_pass_ad_source",
      targetId: id,
      before: JSON.stringify(before),
      after: JSON.stringify(after),
    },
  });

  revalidateAll();
  return { success: true };
}

// [§6-3 "광고소스 활성/비활성"] 별도의 빠른 토글용 액션 — 즉시 반영되어야 하므로 단순화된 시그니처.
export async function toggleOpenPassAdSourceActive(id: number, isActive: boolean): Promise<AdSourceFormState> {
  const session = await verifyAdminSession();
  if (!canWriteReward(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }
  const before = await prisma.openPassAdSource.findUnique({ where: { id } });
  if (!before) return { error: "존재하지 않는 광고소스입니다." };

  await prisma.openPassAdSource.update({ where: { id }, data: { isActive, updatedBy: session.email } });
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: isActive ? "activate" : "deactivate",
      targetType: "open_pass_ad_source",
      targetId: id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive }),
    },
  });
  revalidateAll();
  return { success: true };
}

export async function deleteOpenPassAdSource(
  _prevState: AdSourceFormState,
  formData: FormData
): Promise<AdSourceFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteReward(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const id = Number(formData.get("id"));
  if (!id || Number.isNaN(id)) return { error: "잘못된 요청입니다." };

  const before = await prisma.openPassAdSource.findUnique({ where: { id } });
  if (!before || before.deletedAt) return { error: "존재하지 않는 광고소스입니다." };

  const activeBindingCount = await prisma.openPassProductAdSource.count({ where: { adSourceId: id, isActive: true } });
  if (activeBindingCount > 0) {
    return {
      error: `이 광고소스는 ${activeBindingCount}개의 열림패스 상품에 연결되어 있어 삭제할 수 없습니다. 먼저 상품 연결을 해제해주세요.`,
    };
  }

  await prisma.openPassAdSource.update({
    where: { id },
    data: { status: "deleted", isActive: false, deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "open_pass_ad_source",
      targetId: id,
      before: JSON.stringify(before),
    },
  });

  revalidateAll();
  return { success: true };
}
