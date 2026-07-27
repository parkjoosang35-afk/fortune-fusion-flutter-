"use server";

// "오늘의 행운숫자" 관리자 콘텐츠 Server Actions
// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — 이 기능은 명확히
// 광고(banners)가 아니므로, banners 테이블/actions/API를 재사용하지 않고 완전히 별도로
// 구현한다(LuckyNumberContent 모델, /api/public/lucky-number, cms/lucky-number 화면).
// CMS 메뉴 권한(RBAC_MATRIX.cms)을 그대로 사용해 관리자 접근을 통제한다.
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

// contentType: 'image' -> imageUrl 필수 / 'video' -> videoUrl 필수 / 'script' -> script 필수
const LuckyNumberBaseSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  contentType: z.enum(["image", "video", "script"]).optional().default("image"),
  imageUrl: z.string().optional().nullable(),
  videoUrl: z.string().optional().nullable(),
  script: z.string().optional().nullable(),
  caption: z.string().optional().nullable(),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
});

function refineContentFields<
  T extends { contentType?: string; imageUrl?: string | null; videoUrl?: string | null; script?: string | null }
>(data: T, ctx: z.RefinementCtx) {
  if (data.contentType === "video") {
    if (!data.videoUrl || !/^https?:\/\/.+/.test(data.videoUrl)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "영상 콘텐츠는 올바른 영상 URL이 필요합니다.",
        path: ["videoUrl"],
      });
    }
  } else if (data.contentType === "script") {
    if (!data.script || data.script.trim().length < 5) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "소스(스크립트) 콘텐츠는 HTML 코드를 입력해야 합니다.",
        path: ["script"],
      });
    }
  } else {
    if (!data.imageUrl || !/^https?:\/\/.+/.test(data.imageUrl)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "이미지 콘텐츠는 올바른 이미지 URL이 필요합니다.",
        path: ["imageUrl"],
      });
    }
  }
}

const LuckyNumberSchema = LuckyNumberBaseSchema.superRefine(refineContentFields);

export interface LuckyNumberFormState {
  error?: string;
  success?: boolean;
}

function toDate(v: string | null | undefined): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function readForm(formData: FormData) {
  const imageUrlRaw = formData.get("imageUrl");
  const videoUrlRaw = formData.get("videoUrl");
  const scriptRaw = formData.get("script");
  const captionRaw = formData.get("caption");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  return {
    title: formData.get("title"),
    contentType: formData.get("contentType"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    videoUrl: videoUrlRaw === "" ? null : videoUrlRaw,
    script: scriptRaw === "" ? null : scriptRaw,
    caption: captionRaw === "" ? null : captionRaw,
    sortOrder: formData.get("sortOrder"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
  };
}

// ── 생성 ──
export async function createLuckyNumberContent(
  _prevState: LuckyNumberFormState,
  formData: FormData
): Promise<LuckyNumberFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = LuckyNumberSchema.safeParse(readForm(formData));
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { startAt, endAt, ...rest } = parsed.data;

  const created = await prisma.luckyNumberContent.create({
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
      targetType: "lucky_number_content",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/cms/lucky-number");
  return { success: true };
}

// ── 수정 ──
const UpdateLuckyNumberSchema = LuckyNumberBaseSchema.extend({
  id: z.coerce.number().int().positive(),
}).superRefine(refineContentFields);

export async function updateLuckyNumberContent(
  _prevState: LuckyNumberFormState,
  formData: FormData
): Promise<LuckyNumberFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdateLuckyNumberSchema.safeParse({
    id: formData.get("id"),
    ...readForm(formData),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, startAt, endAt, ...rest } = parsed.data;

  const before = await prisma.luckyNumberContent.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  const after = await prisma.luckyNumberContent.update({
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
      targetType: "lucky_number_content",
      targetId: id,
      before: JSON.stringify({ title: before.title, isActive: before.isActive }),
      after: JSON.stringify({ title: after.title, isActive: after.isActive }),
    },
  });

  revalidatePath("/cms/lucky-number");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteLuckyNumberSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteLuckyNumberContent(
  _prevState: LuckyNumberFormState,
  formData: FormData
): Promise<LuckyNumberFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteLuckyNumberSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckyNumberContent.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  await prisma.luckyNumberContent.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "lucky_number_content",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/cms/lucky-number");
  return { success: true };
}

// ── 활성/비활성 토글 ──
const ToggleLuckyNumberSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function toggleLuckyNumberContentActive(
  _prevState: LuckyNumberFormState,
  formData: FormData
): Promise<LuckyNumberFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleLuckyNumberSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.luckyNumberContent.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 콘텐츠입니다." };
  }

  await prisma.luckyNumberContent.update({
    where: { id: parsed.data.id },
    data: { isActive: parsed.data.isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isActive ? "activate" : "deactivate",
      targetType: "lucky_number_content",
      targetId: parsed.data.id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive: parsed.data.isActive }),
    },
  });

  revalidatePath("/cms/lucky-number");
  return { success: true };
}
