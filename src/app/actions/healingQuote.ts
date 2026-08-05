"use server";

// "힐링 문구" 관리자 콘텐츠 Server Actions.
// [사용자 요청] 홈 화면의 "오늘의 운세 이야기" 섹션(운세 기능)을 완전히 삭제하고, 그 자리를
// 좋은 글귀/힐링 문구/긍정 명언/응원의 한마디 등으로 대체한다. 이 기능은 운세(daily fortune)와도
// 광고(banners)와도 무관한 완전히 별도의 콘텐츠이며, LuckyNumberContent 패턴을 그대로 따르되
// 단일 슬롯이 아니라 "활성 문구 여러 건을 앱이 통째로 받아 1분마다 순환 노출"하는 구조이다.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteCms(roleCode: string): boolean {
  return canWriteMenu(roleCode, "cms");
}

function canDeleteCms(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "cms");
}

const HealingQuoteBaseSchema = z.object({
  content: z.string().min(1, "문구 내용을 입력해주세요."),
  author: z.string().optional().nullable(),
  category: z.string().optional().default("healing"),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
});

export interface HealingQuoteFormState {
  error?: string;
  success?: boolean;
}

function toDate(v: string | null | undefined): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function readForm(formData: FormData) {
  const authorRaw = formData.get("author");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  return {
    content: formData.get("content"),
    author: authorRaw === "" ? null : authorRaw,
    category: formData.get("category") || "healing",
    sortOrder: formData.get("sortOrder"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
  };
}

// ── 생성 ──
export async function createHealingQuote(
  _prevState: HealingQuoteFormState,
  formData: FormData
): Promise<HealingQuoteFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = HealingQuoteBaseSchema.safeParse(readForm(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { startAt, endAt, ...rest } = parsed.data;

  const created = await prisma.healingQuote.create({
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
      targetType: "healing_quote",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/cms/healing-quotes");
  return { success: true };
}

// ── 수정 ──
const UpdateHealingQuoteSchema = HealingQuoteBaseSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateHealingQuote(
  _prevState: HealingQuoteFormState,
  formData: FormData
): Promise<HealingQuoteFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateHealingQuoteSchema.safeParse({
    id: formData.get("id"),
    ...readForm(formData),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, startAt, endAt, ...rest } = parsed.data;

  const before = await prisma.healingQuote.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  const after = await prisma.healingQuote.update({
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
      targetType: "healing_quote",
      targetId: id,
      before: JSON.stringify({ content: before.content, isActive: before.isActive }),
      after: JSON.stringify({ content: after.content, isActive: after.isActive }),
    },
  });

  revalidatePath("/cms/healing-quotes");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteHealingQuoteSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteHealingQuote(
  _prevState: HealingQuoteFormState,
  formData: FormData
): Promise<HealingQuoteFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteHealingQuoteSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.healingQuote.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  await prisma.healingQuote.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "healing_quote",
      targetId: parsed.data.id,
      before: JSON.stringify({ content: before.content }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/cms/healing-quotes");
  return { success: true };
}

// ── 활성/비활성 토글 ──
const ToggleHealingQuoteSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function toggleHealingQuoteActive(
  _prevState: HealingQuoteFormState,
  formData: FormData
): Promise<HealingQuoteFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleHealingQuoteSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.healingQuote.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  await prisma.healingQuote.update({
    where: { id: parsed.data.id },
    data: { isActive: parsed.data.isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isActive ? "activate" : "deactivate",
      targetType: "healing_quote",
      targetId: parsed.data.id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive: parsed.data.isActive }),
    },
  });

  revalidatePath("/cms/healing-quotes");
  return { success: true };
}
