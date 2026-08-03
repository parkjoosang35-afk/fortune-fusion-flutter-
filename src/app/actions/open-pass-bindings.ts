"use server";

// 열림패스 상품(PassPolicy) - 첨부파일/광고소스 바인딩 관리 Server Actions
// [사용자 요청] §5/§6-4/§8-4/§8-5
// admin-simulation.ts와 동일하게 "일반 함수 + useTransition 직접 호출" 패턴을 쓴다
// (바인딩 UI는 상품 선택 → 여러 첨부파일/광고소스를 동적으로 추가/해제하는 구조라
// FormData보다 타입 있는 함수 시그니처가 자연스럽다).
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";

export interface BindingResult {
  success: boolean;
  message: string;
}

async function requireWrite() {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "reward")) {
    return { ok: false as const, result: { success: false, message: "이 작업을 수행할 권한이 없습니다." } };
  }
  return { ok: true as const, session };
}

function revalidateAll() {
  revalidatePath("/reward/open-pass-bindings");
  revalidatePath("/reward/pass-policies");
  revalidatePath("/reward/open-pass-attachments");
  revalidatePath("/reward/open-pass-ad-sources");
  revalidatePath("/reward/test-lab");
}

async function logAction(params: {
  adminId: number;
  action: string;
  targetType: string;
  targetId?: number | null;
  before?: unknown;
  after?: unknown;
}) {
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: params.adminId,
      action: params.action,
      targetType: params.targetType,
      targetId: params.targetId ?? null,
      before: params.before != null ? JSON.stringify(params.before) : null,
      after: params.after != null ? JSON.stringify(params.after) : null,
    },
  });
}

// ════════════════════════════════════════════════════════════════
// 상품 - 첨부파일 바인딩
// ════════════════════════════════════════════════════════════════

export async function bindAttachmentToProduct(input: {
  passPolicyId: number;
  attachmentId: number;
  usageType: string;
  displayOrder?: number;
  isPrimary?: boolean;
}): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  const [policy, attachment] = await Promise.all([
    prisma.passPolicy.findUnique({ where: { id: input.passPolicyId } }),
    prisma.openPassAttachment.findUnique({ where: { id: input.attachmentId } }),
  ]);
  if (!policy || policy.deletedAt) return { success: false, message: "존재하지 않는 열림패스 상품입니다." };
  if (!attachment || attachment.deletedAt) return { success: false, message: "존재하지 않는 첨부파일입니다." };

  const existing = await prisma.openPassProductAttachment.findUnique({
    where: {
      passPolicyId_attachmentId_usageType: {
        passPolicyId: input.passPolicyId,
        attachmentId: input.attachmentId,
        usageType: input.usageType,
      },
    },
  });
  if (existing) {
    return { success: false, message: "이미 동일한 용도로 연결되어 있습니다." };
  }

  // isPrimary=true로 지정하면 같은 usageType 내 기존 대표는 해제(대표 1개 원칙 — §5 "우선순위 기준 대표 1개 선택").
  if (input.isPrimary) {
    await prisma.openPassProductAttachment.updateMany({
      where: { passPolicyId: input.passPolicyId, usageType: input.usageType, isPrimary: true },
      data: { isPrimary: false },
    });
  }

  const created = await prisma.openPassProductAttachment.create({
    data: {
      passPolicyId: input.passPolicyId,
      attachmentId: input.attachmentId,
      usageType: input.usageType,
      displayOrder: input.displayOrder ?? 0,
      isPrimary: input.isPrimary ?? false,
    },
  });

  await logAction({
    adminId: auth.session.adminUserId,
    action: "bind_attachment",
    targetType: "open_pass_product_attachment",
    targetId: created.id,
    after: created,
  });

  revalidateAll();
  return { success: true, message: `"${attachment.fileName}"을 "${policy.name}"의 ${input.usageType} 위치에 연결했습니다.` };
}

export async function unbindAttachmentFromProduct(bindingId: number): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  const before = await prisma.openPassProductAttachment.findUnique({ where: { id: bindingId } });
  if (!before) return { success: false, message: "존재하지 않는 연결입니다." };

  await prisma.openPassProductAttachment.delete({ where: { id: bindingId } });

  await logAction({
    adminId: auth.session.adminUserId,
    action: "unbind_attachment",
    targetType: "open_pass_product_attachment",
    targetId: bindingId,
    before,
  });

  revalidateAll();
  return { success: true, message: "첨부파일 연결을 해제했습니다." };
}

export async function toggleProductAttachmentActive(bindingId: number, isActive: boolean): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;
  const before = await prisma.openPassProductAttachment.findUnique({ where: { id: bindingId } });
  if (!before) return { success: false, message: "존재하지 않는 연결입니다." };
  await prisma.openPassProductAttachment.update({ where: { id: bindingId }, data: { isActive } });
  revalidateAll();
  return { success: true, message: isActive ? "연결을 활성화했습니다." : "연결을 비활성화했습니다." };
}

// 상품의 대표(hero)/광고유도(promo)/공통 fallback 첨부파일 지정 — PassPolicy에 직접 반영.
export async function setProductAttachmentSlot(input: {
  passPolicyId: number;
  slot: "hero" | "promo" | "fallback";
  attachmentId: number | null;
}): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  if (input.attachmentId) {
    const attachment = await prisma.openPassAttachment.findUnique({ where: { id: input.attachmentId } });
    if (!attachment || attachment.deletedAt) return { success: false, message: "존재하지 않는 첨부파일입니다." };
  }

  const field =
    input.slot === "hero" ? "heroAttachmentId" : input.slot === "promo" ? "promoAttachmentId" : "fallbackAttachmentId";
  const before = await prisma.passPolicy.findUnique({ where: { id: input.passPolicyId } });
  if (!before) return { success: false, message: "존재하지 않는 열림패스 상품입니다." };

  await prisma.passPolicy.update({
    where: { id: input.passPolicyId },
    data: { [field]: input.attachmentId },
  });

  await logAction({
    adminId: auth.session.adminUserId,
    action: `set_${input.slot}_attachment`,
    targetType: "pass_policy",
    targetId: input.passPolicyId,
    before: { [field]: (before as unknown as Record<string, unknown>)[field] },
    after: { [field]: input.attachmentId },
  });

  revalidateAll();
  const slotLabel = { hero: "대표 배너", promo: "광고유도 배너", fallback: "공통 fallback 소재" }[input.slot];
  return { success: true, message: `${slotLabel}을 지정했습니다.` };
}

// ════════════════════════════════════════════════════════════════
// 상품 - 광고소스 바인딩
// ════════════════════════════════════════════════════════════════

export async function bindAdSourceToProduct(input: {
  passPolicyId: number;
  adSourceId: number;
  priority?: number;
  isPrimary?: boolean;
  platform?: string; // all/android/ios/web
}): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  const platform = input.platform ?? "all";
  const [policy, adSource] = await Promise.all([
    prisma.passPolicy.findUnique({ where: { id: input.passPolicyId } }),
    prisma.openPassAdSource.findUnique({ where: { id: input.adSourceId } }),
  ]);
  if (!policy || policy.deletedAt) return { success: false, message: "존재하지 않는 열림패스 상품입니다." };
  if (!adSource || adSource.deletedAt) return { success: false, message: "존재하지 않는 광고소스입니다." };

  const existing = await prisma.openPassProductAdSource.findUnique({
    where: {
      passPolicyId_adSourceId_platform: { passPolicyId: input.passPolicyId, adSourceId: input.adSourceId, platform },
    },
  });
  if (existing) return { success: false, message: "이미 연결된 광고소스입니다." };

  if (input.isPrimary) {
    await prisma.openPassProductAdSource.updateMany({
      where: { passPolicyId: input.passPolicyId, platform, isPrimary: true },
      data: { isPrimary: false },
    });
  }

  const created = await prisma.openPassProductAdSource.create({
    data: {
      passPolicyId: input.passPolicyId,
      adSourceId: input.adSourceId,
      priority: input.priority ?? 0,
      isPrimary: input.isPrimary ?? false,
      platform,
    },
  });

  await logAction({
    adminId: auth.session.adminUserId,
    action: "bind_ad_source",
    targetType: "open_pass_product_ad_source",
    targetId: created.id,
    after: created,
  });

  revalidateAll();
  return { success: true, message: `"${adSource.sourceName}"을 "${policy.name}"에 연결했습니다. (platform=${platform})` };
}

export async function unbindAdSourceFromProduct(bindingId: number): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  const before = await prisma.openPassProductAdSource.findUnique({ where: { id: bindingId } });
  if (!before) return { success: false, message: "존재하지 않는 연결입니다." };

  await prisma.openPassProductAdSource.delete({ where: { id: bindingId } });

  await logAction({
    adminId: auth.session.adminUserId,
    action: "unbind_ad_source",
    targetType: "open_pass_product_ad_source",
    targetId: bindingId,
    before,
  });

  revalidateAll();
  return { success: true, message: "광고소스 연결을 해제했습니다." };
}

export async function updateProductAdSourceBinding(input: {
  bindingId: number;
  priority?: number;
  isPrimary?: boolean;
  isActive?: boolean;
}): Promise<BindingResult> {
  const auth = await requireWrite();
  if (!auth.ok) return auth.result;

  const before = await prisma.openPassProductAdSource.findUnique({ where: { id: input.bindingId } });
  if (!before) return { success: false, message: "존재하지 않는 연결입니다." };

  if (input.isPrimary) {
    await prisma.openPassProductAdSource.updateMany({
      where: { passPolicyId: before.passPolicyId, platform: before.platform, isPrimary: true },
      data: { isPrimary: false },
    });
  }

  await prisma.openPassProductAdSource.update({
    where: { id: input.bindingId },
    data: {
      priority: input.priority ?? before.priority,
      isPrimary: input.isPrimary ?? before.isPrimary,
      isActive: input.isActive ?? before.isActive,
    },
  });

  revalidateAll();
  return { success: true, message: "우선순위/failover 설정을 업데이트했습니다." };
}

// ════════════════════════════════════════════════════════════════
// 조회: 바인딩 화면에서 상품별 현황을 한 번에 보여주기 위한 헬퍼
// ════════════════════════════════════════════════════════════════
export async function getProductBindingSnapshot(passPolicyId: number) {
  const [policy, attachmentBindings, adSourceBindings] = await Promise.all([
    prisma.passPolicy.findUnique({ where: { id: passPolicyId } }),
    prisma.openPassProductAttachment.findMany({
      where: { passPolicyId },
      include: { attachment: true },
      orderBy: [{ usageType: "asc" }, { displayOrder: "asc" }],
    }),
    prisma.openPassProductAdSource.findMany({
      where: { passPolicyId },
      include: { adSource: true },
      orderBy: [{ platform: "asc" }, { priority: "asc" }],
    }),
  ]);
  return { policy, attachmentBindings, adSourceBindings };
}
