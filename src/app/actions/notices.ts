"use server";

// CMS 공지사항 관리 Server Actions
// 05_Admin_System_Design.md §3.8 "공지사항 관리" — 04A N-9 notices CRUD
// (고정 여부). banners.ts/popups.ts 패턴을 그대로 재사용한다.
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

export interface NoticeFormState {
  error?: string;
  success?: boolean;
}

const NoticeSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  content: z.string().min(1, "내용을 입력해주세요.(04A N-9 명시: NOT NULL)"),
  isPinned: z.coerce.boolean().optional().default(false),
});

// ── 생성 ──
export async function createNotice(
  _prevState: NoticeFormState,
  formData: FormData
): Promise<NoticeFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = NoticeSchema.safeParse({
    title: formData.get("title"),
    content: formData.get("content"),
    isPinned: formData.get("isPinned") === "on" || formData.get("isPinned") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.notice.create({
    data: {
      title: parsed.data.title,
      content: parsed.data.content,
      isPinned: parsed.data.isPinned,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "notice",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ title: created.title, isPinned: created.isPinned }),
    },
  });

  revalidatePath("/cms/notices");
  return { success: true };
}

// ── 수정 ──
const UpdateNoticeSchema = NoticeSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateNotice(
  _prevState: NoticeFormState,
  formData: FormData
): Promise<NoticeFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateNoticeSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    content: formData.get("content"),
    isPinned: formData.get("isPinned") === "on" || formData.get("isPinned") === "true",
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.notice.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 공지사항입니다." };
  }

  const after = await prisma.notice.update({
    where: { id: parsed.data.id },
    data: {
      title: parsed.data.title,
      content: parsed.data.content,
      isPinned: parsed.data.isPinned,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "notice",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title, isPinned: before.isPinned }),
      after: JSON.stringify({ title: after.title, isPinned: after.isPinned }),
    },
  });

  revalidatePath("/cms/notices");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteNoticeSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteNotice(
  _prevState: NoticeFormState,
  formData: FormData
): Promise<NoticeFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteNoticeSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.notice.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 공지사항입니다." };
  }

  await prisma.notice.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "notice",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/cms/notices");
  return { success: true };
}

// ── 고정/고정해제 토글 ──
const TogglePinSchema = z.object({
  id: z.coerce.number().int().positive(),
  isPinned: z.coerce.boolean(),
});

export async function toggleNoticePinned(
  _prevState: NoticeFormState,
  formData: FormData
): Promise<NoticeFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = TogglePinSchema.safeParse({
    id: formData.get("id"),
    isPinned: formData.get("isPinned") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.notice.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 공지사항입니다." };
  }

  await prisma.notice.update({
    where: { id: parsed.data.id },
    data: { isPinned: parsed.data.isPinned, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isPinned ? "pin" : "unpin",
      targetType: "notice",
      targetId: parsed.data.id,
      before: JSON.stringify({ isPinned: before.isPinned }),
      after: JSON.stringify({ isPinned: parsed.data.isPinned }),
    },
  });

  revalidatePath("/cms/notices");
  return { success: true };
}
