"use server";

// CMS FAQ 관리 Server Actions
// 05_Admin_System_Design.md §3.8 "FAQ 관리" — 04A N-10 faqs CRUD
// (카테고리/정렬순서). notices.ts 패턴을 그대로 재사용한다.
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

export interface FaqFormState {
  error?: string;
  success?: boolean;
}

const FaqSchema = z.object({
  category: z.string().min(1, "카테고리를 입력해주세요."),
  question: z.string().min(1, "질문을 입력해주세요."),
  answer: z.string().min(1, "답변을 입력해주세요.(04A N-10 명시: NOT NULL)"),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
});

// ── 생성 ──
export async function createFaq(
  _prevState: FaqFormState,
  formData: FormData
): Promise<FaqFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = FaqSchema.safeParse({
    category: formData.get("category"),
    question: formData.get("question"),
    answer: formData.get("answer"),
    sortOrder: formData.get("sortOrder"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.faq.create({
    data: {
      category: parsed.data.category,
      question: parsed.data.question,
      answer: parsed.data.answer,
      sortOrder: parsed.data.sortOrder,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "faq",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ category: created.category, question: created.question }),
    },
  });

  revalidatePath("/cms/faqs");
  return { success: true };
}

// ── 수정 ──
const UpdateFaqSchema = FaqSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateFaq(
  _prevState: FaqFormState,
  formData: FormData
): Promise<FaqFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateFaqSchema.safeParse({
    id: formData.get("id"),
    category: formData.get("category"),
    question: formData.get("question"),
    answer: formData.get("answer"),
    sortOrder: formData.get("sortOrder"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.faq.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 FAQ입니다." };
  }

  const after = await prisma.faq.update({
    where: { id: parsed.data.id },
    data: {
      category: parsed.data.category,
      question: parsed.data.question,
      answer: parsed.data.answer,
      sortOrder: parsed.data.sortOrder,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "faq",
      targetId: parsed.data.id,
      before: JSON.stringify({ category: before.category, question: before.question }),
      after: JSON.stringify({ category: after.category, question: after.question }),
    },
  });

  revalidatePath("/cms/faqs");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteFaqSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteFaq(
  _prevState: FaqFormState,
  formData: FormData
): Promise<FaqFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteFaqSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.faq.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 FAQ입니다." };
  }

  await prisma.faq.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "faq",
      targetId: parsed.data.id,
      before: JSON.stringify({ question: before.question }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/cms/faqs");
  return { success: true };
}
