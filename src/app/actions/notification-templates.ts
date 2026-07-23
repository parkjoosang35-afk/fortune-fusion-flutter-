"use server";

// CMS류 알림 템플릿 관리 Server Actions
// 05_Admin_System_Design.md §3.9 "알림 템플릿 관리" — 04A N-1
// notification_templates CRUD(푸시/인앱 공용 템플릿). notices.ts/faqs.ts
// 패턴을 그대로 재사용한다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteNotifications(roleCode: string): boolean {
  return canWriteMenu(roleCode, "notifications");
}

function canDeleteNotifications(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "notifications");
}

export interface NotificationTemplateFormState {
  error?: string;
  success?: boolean;
}

const TemplateSchema = z.object({
  code: z.string().min(1, "코드를 입력해주세요.(04A N-1 명시: NOT NULL, UNIQUE)"),
  title: z.string().min(1, "제목을 입력해주세요."),
  body: z.string().min(1, "본문을 입력해주세요.(04A N-1 명시: NOT NULL)"),
  deepLink: z
    .string()
    .optional()
    .transform((v) => (v && v.trim().length > 0 ? v.trim() : null)),
});

// ── 생성 ──
export async function createNotificationTemplate(
  _prevState: NotificationTemplateFormState,
  formData: FormData
): Promise<NotificationTemplateFormState> {
  const session = await verifyAdminSession();
  if (!canWriteNotifications(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = TemplateSchema.safeParse({
    code: formData.get("code"),
    title: formData.get("title"),
    body: formData.get("body"),
    deepLink: formData.get("deepLink"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const dup = await prisma.notificationTemplate.findUnique({ where: { code: parsed.data.code } });
  if (dup) {
    return { error: "이미 존재하는 템플릿 코드입니다.(04A N-1 명시: UNIQUE)" };
  }

  const created = await prisma.notificationTemplate.create({
    data: {
      code: parsed.data.code,
      title: parsed.data.title,
      body: parsed.data.body,
      deepLink: parsed.data.deepLink,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "notification_template",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ code: created.code, title: created.title }),
    },
  });

  revalidatePath("/notifications/templates");
  return { success: true };
}

// ── 수정 ──
const UpdateTemplateSchema = TemplateSchema.extend({ id: z.coerce.number().int().positive() });

export async function updateNotificationTemplate(
  _prevState: NotificationTemplateFormState,
  formData: FormData
): Promise<NotificationTemplateFormState> {
  const session = await verifyAdminSession();
  if (!canWriteNotifications(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateTemplateSchema.safeParse({
    id: formData.get("id"),
    code: formData.get("code"),
    title: formData.get("title"),
    body: formData.get("body"),
    deepLink: formData.get("deepLink"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.notificationTemplate.findUnique({
    where: { id: parsed.data.id },
  });
  if (!before) {
    return { error: "존재하지 않는 템플릿입니다." };
  }

  if (before.code !== parsed.data.code) {
    const dup = await prisma.notificationTemplate.findUnique({
      where: { code: parsed.data.code },
    });
    if (dup) {
      return { error: "이미 존재하는 템플릿 코드입니다.(04A N-1 명시: UNIQUE)" };
    }
  }

  const after = await prisma.notificationTemplate.update({
    where: { id: parsed.data.id },
    data: {
      code: parsed.data.code,
      title: parsed.data.title,
      body: parsed.data.body,
      deepLink: parsed.data.deepLink,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "notification_template",
      targetId: parsed.data.id,
      before: JSON.stringify({ code: before.code, title: before.title }),
      after: JSON.stringify({ code: after.code, title: after.title }),
    },
  });

  revalidatePath("/notifications/templates");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteTemplateSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteNotificationTemplate(
  _prevState: NotificationTemplateFormState,
  formData: FormData
): Promise<NotificationTemplateFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteNotifications(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteTemplateSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.notificationTemplate.findUnique({
    where: { id: parsed.data.id },
  });
  if (!before) {
    return { error: "존재하지 않는 템플릿입니다." };
  }

  await prisma.notificationTemplate.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "notification_template",
      targetId: parsed.data.id,
      before: JSON.stringify({ code: before.code }),
      after: JSON.stringify({ deleted: true }),
    },
  });

  revalidatePath("/notifications/templates");
  return { success: true };
}
