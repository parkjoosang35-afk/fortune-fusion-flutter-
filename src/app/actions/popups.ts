"use server";

// CMS 팝업 관리 Server Actions
// 05_Admin_System_Design.md §3.8 "팝업 관리" — 04A N-8 popups CRUD(노출 조건,
// 1회성/반복 설정). banners.ts(aa0fad2) 패턴을 그대로 재사용한다.
// [display_condition] JSONB→String 매핑. {once: boolean, segment?: string}
//   형태로 저장한다("1회성/반복 설정" + 세그먼트 조건을 하나의 JSON 필드로 표현
//   — 04A 컬럼 추가 없이 05 요구사항을 JSON 내부 스키마로 수용).
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
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

export interface PopupFormState {
  error?: string;
  success?: boolean;
}

function toDate(v: string | null | undefined): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function displayConditionToJson(once: boolean, segment: string | null): string {
  const cond: { once: boolean; segment?: string } = { once };
  if (segment) cond.segment = segment;
  return JSON.stringify(cond);
}

const PopupSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  imageUrl: z
    .string()
    .optional()
    .nullable()
    .refine((v) => !v || /^https?:\/\/.+/.test(v), "올바른 URL 형식이 아닙니다."),
  linkUrl: z
    .string()
    .optional()
    .nullable()
    .refine((v) => !v || /^https?:\/\/.+/.test(v), "올바른 URL 형식이 아닙니다."),
  once: z.coerce.boolean().optional().default(false),
  segment: z.string().optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
  startAt: z.string().min(1, "노출 시작일은 필수입니다.(04A N-8 명시: NOT NULL)"),
  endAt: z.string().min(1, "노출 종료일은 필수입니다.(04A N-8 명시: NOT NULL)"),
});

// ── 생성 ──
export async function createPopup(
  _prevState: PopupFormState,
  formData: FormData
): Promise<PopupFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const linkUrlRaw = formData.get("linkUrl");
  const segmentRaw = formData.get("segment");
  const parsed = PopupSchema.safeParse({
    title: formData.get("title"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    linkUrl: linkUrlRaw === "" ? null : linkUrlRaw,
    once: formData.get("once") === "on" || formData.get("once") === "true",
    segment: segmentRaw === "" ? null : segmentRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const startAt = toDate(parsed.data.startAt);
  const endAt = toDate(parsed.data.endAt);
  if (!startAt || !endAt) {
    return { error: "날짜 형식이 올바르지 않습니다." };
  }
  if (endAt < startAt) {
    return { error: "종료일은 시작일보다 이후여야 합니다." };
  }

  const created = await prisma.popup.create({
    data: {
      title: parsed.data.title,
      imageUrl: parsed.data.imageUrl ?? null,
      linkUrl: parsed.data.linkUrl ?? null,
      displayCondition: displayConditionToJson(parsed.data.once, parsed.data.segment ?? null),
      startAt,
      endAt,
      isActive: parsed.data.isActive,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "popup",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ title: created.title, startAt, endAt, isActive: created.isActive }),
    },
  });

  revalidatePath("/cms/popups");
  return { success: true };
}

// ── 수정 ──
const UpdatePopupSchema = PopupSchema.extend({ id: z.coerce.number().int().positive() });

export async function updatePopup(
  _prevState: PopupFormState,
  formData: FormData
): Promise<PopupFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const linkUrlRaw = formData.get("linkUrl");
  const segmentRaw = formData.get("segment");
  const parsed = UpdatePopupSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    linkUrl: linkUrlRaw === "" ? null : linkUrlRaw,
    once: formData.get("once") === "on" || formData.get("once") === "true",
    segment: segmentRaw === "" ? null : segmentRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: formData.get("startAt"),
    endAt: formData.get("endAt"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const startAt = toDate(parsed.data.startAt);
  const endAt = toDate(parsed.data.endAt);
  if (!startAt || !endAt) {
    return { error: "날짜 형식이 올바르지 않습니다." };
  }
  if (endAt < startAt) {
    return { error: "종료일은 시작일보다 이후여야 합니다." };
  }

  const before = await prisma.popup.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 팝업입니다." };
  }

  const after = await prisma.popup.update({
    where: { id: parsed.data.id },
    data: {
      title: parsed.data.title,
      imageUrl: parsed.data.imageUrl ?? null,
      linkUrl: parsed.data.linkUrl ?? null,
      displayCondition: displayConditionToJson(parsed.data.once, parsed.data.segment ?? null),
      startAt,
      endAt,
      isActive: parsed.data.isActive,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "popup",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title, isActive: before.isActive }),
      after: JSON.stringify({ title: after.title, isActive: after.isActive }),
    },
  });

  revalidatePath("/cms/popups");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeletePopupSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deletePopup(
  _prevState: PopupFormState,
  formData: FormData
): Promise<PopupFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeletePopupSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.popup.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 팝업입니다." };
  }

  await prisma.popup.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "popup",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/cms/popups");
  return { success: true };
}

// ── 활성/비활성 토글 ──
const TogglePopupSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function togglePopupActive(
  _prevState: PopupFormState,
  formData: FormData
): Promise<PopupFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = TogglePopupSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.popup.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 팝업입니다." };
  }

  await prisma.popup.update({
    where: { id: parsed.data.id },
    data: { isActive: parsed.data.isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isActive ? "activate" : "deactivate",
      targetType: "popup",
      targetId: parsed.data.id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive: parsed.data.isActive }),
    },
  });

  revalidatePath("/cms/popups");
  return { success: true };
}
