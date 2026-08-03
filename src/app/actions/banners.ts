"use server";

// CMS 배너(제휴 광고) 관리 Server Actions
// 05_Admin_System_Design.md §3.8 "배너 관리" — 04A N-7 banners CRUD
// [스코프 결정] 쿠팡파트너스 등 제휴사 광고 배너를 이 화면으로 관리한다.
//   link_url에 제휴사 어필리에이트 링크를 입력하는 구조 — "가장 쉬운 관리 형태" 요청에 따라
//   04A 원본 스펙 중 display_condition(JSON 조건편집기, popups 전용)은 배제하고
//   position_code/sort_order/start_at/end_at/is_active만으로 단순 구성.
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

// [광고소스 지원] adType='image' -> 기존 이미지 URL + 링크 방식.
//   adType='script' -> 쿠팡파트너스 등 제휴사가 발급하는 원본 광고 태그(iframe/script)를
//   그대로 저장한다. 이 경우 imageUrl은 필요 없고 adScript가 필수다.
// (ZodEffects는 .extend()를 지원하지 않으므로 base 객체 스키마와 refine 로직을 분리한다.)
const BannerBaseSchema = z.object({
  title: z.string().min(1, "제목을 입력해주세요."),
  adType: z.enum(["image", "script"]).optional().default("image"),
  imageUrl: z.string().optional().nullable(),
  adScript: z.string().optional().nullable(),
  linkUrl: z
    .string()
    .optional()
    .nullable()
    .refine((v) => !v || /^https?:\/\/.+/.test(v), "올바른 URL 형식이 아닙니다."),
  // [프리패스 단순화 - CMS 쿠팡파트너스 배너 연동] positionCode='open_pass'는
  // "CMS 쿠팡파트너스 배너 = 프리패스 광고" 요구사항에 따라 추가된 값이다.
  // 이 값으로 등록된(활성 + 노출기간 내) 배너 1건이 /api/public/pass/policies
  // 응답의 광고 이미지/링크/스크립트로 그대로 병합되어 앱에 노출된다.
  positionCode: z.enum(["home_top", "home_middle", "home_bottom", "open_pass"]),
  sortOrder: z.coerce.number().int().min(0).optional().default(0),
  isActive: z.coerce.boolean().optional().default(true),
  startAt: z.string().optional().nullable(),
  endAt: z.string().optional().nullable(),
});

function refineAdFields<T extends { adType?: string; imageUrl?: string | null; adScript?: string | null }>(
  data: T,
  ctx: z.RefinementCtx
) {
  if (data.adType === "script") {
    if (!data.adScript || data.adScript.trim().length < 10) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "광고소스형은 제휴사가 제공한 스크립트/iframe 코드를 입력해야 합니다.",
        path: ["adScript"],
      });
    }
  } else {
    if (!data.imageUrl || !/^https?:\/\/.+/.test(data.imageUrl)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "이미지형 광고는 올바른 이미지 URL이 필요합니다.",
        path: ["imageUrl"],
      });
    }
  }
}

const BannerSchema = BannerBaseSchema.superRefine(refineAdFields);

export interface BannerFormState {
  error?: string;
  success?: boolean;
}

function toDate(v: string | null | undefined): Date | null {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

// ── 생성 ──
export async function createBanner(
  _prevState: BannerFormState,
  formData: FormData
): Promise<BannerFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const linkUrlRaw = formData.get("linkUrl");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  const imageUrlRaw = formData.get("imageUrl");
  const adScriptRaw = formData.get("adScript");
  const parsed = BannerSchema.safeParse({
    title: formData.get("title"),
    adType: formData.get("adType"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    adScript: adScriptRaw === "" ? null : adScriptRaw,
    linkUrl: linkUrlRaw === "" ? null : linkUrlRaw,
    positionCode: formData.get("positionCode"),
    sortOrder: formData.get("sortOrder"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { startAt, endAt, ...rest } = parsed.data;

  const created = await prisma.banner.create({
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
      targetType: "banner",
      targetId: created.id,
      before: null,
      after: JSON.stringify(parsed.data),
    },
  });

  revalidatePath("/cms/banners");
  return { success: true };
}

// ── 수정 ──
const UpdateBannerSchema = BannerBaseSchema.extend({
  id: z.coerce.number().int().positive(),
}).superRefine(refineAdFields);

export async function updateBanner(
  _prevState: BannerFormState,
  formData: FormData
): Promise<BannerFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const linkUrlRaw = formData.get("linkUrl");
  const startAtRaw = formData.get("startAt");
  const endAtRaw = formData.get("endAt");
  const imageUrlRaw = formData.get("imageUrl");
  const adScriptRaw = formData.get("adScript");
  const parsed = UpdateBannerSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    adType: formData.get("adType"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    adScript: adScriptRaw === "" ? null : adScriptRaw,
    linkUrl: linkUrlRaw === "" ? null : linkUrlRaw,
    positionCode: formData.get("positionCode"),
    sortOrder: formData.get("sortOrder"),
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
    startAt: startAtRaw === "" ? null : startAtRaw,
    endAt: endAtRaw === "" ? null : endAtRaw,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, startAt, endAt, ...rest } = parsed.data;

  const before = await prisma.banner.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 배너입니다." };
  }

  const after = await prisma.banner.update({
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
      targetType: "banner",
      targetId: id,
      before: JSON.stringify({
        title: before.title,
        linkUrl: before.linkUrl,
        positionCode: before.positionCode,
        isActive: before.isActive,
      }),
      after: JSON.stringify({
        title: after.title,
        linkUrl: after.linkUrl,
        positionCode: after.positionCode,
        isActive: after.isActive,
      }),
    },
  });

  revalidatePath("/cms/banners");
  return { success: true };
}

// ── 삭제 (soft delete) ──
const DeleteBannerSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteBanner(
  _prevState: BannerFormState,
  formData: FormData
): Promise<BannerFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteCms(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteBannerSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.banner.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 배너입니다." };
  }

  await prisma.banner.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "banner",
      targetId: parsed.data.id,
      before: JSON.stringify({ title: before.title }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath("/cms/banners");
  return { success: true };
}

// ── 활성/비활성 토글 (삭제와 별개 — soft-delete 없이 노출만 껐다 켰다) ──
const ToggleBannerSchema = z.object({
  id: z.coerce.number().int().positive(),
  isActive: z.coerce.boolean(),
});

export async function toggleBannerActive(
  _prevState: BannerFormState,
  formData: FormData
): Promise<BannerFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = ToggleBannerSchema.safeParse({
    id: formData.get("id"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.banner.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 배너입니다." };
  }

  await prisma.banner.update({
    where: { id: parsed.data.id },
    data: { isActive: parsed.data.isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: parsed.data.isActive ? "activate" : "deactivate",
      targetType: "banner",
      targetId: parsed.data.id,
      before: JSON.stringify({ isActive: before.isActive }),
      after: JSON.stringify({ isActive: parsed.data.isActive }),
    },
  });

  revalidatePath("/cms/banners");
  return { success: true };
}

// ── [운세 앱 개발 프롬프트-Task3] 포지션별 마스터 ON/OFF 스위치 ──
// 대시보드/CMS 배너 관리 화면에서 "home_top 전체 끄기"처럼 특정 노출 위치의
// 모든 배너를 한 번에 켜고 끌 수 있게 하는 일괄 토글 액션.
// (개별 토글(toggleBannerActive)과 달리 targetId가 다건이라 operation_logs에는
//  targetType="banner_position"으로 기록하고, targetId는 영향받은 배너 중 하나를
//  대표로 남긴다 — targetId 컬럼이 Int? 단일값이라 폴리모픽 관례를 따름.)
const BulkTogglePositionSchema = z.object({
  positionCode: z.enum(["home_top", "home_middle", "home_bottom", "open_pass"]),
  isActive: z.coerce.boolean(),
});

export async function bulkToggleBannersByPosition(
  _prevState: BannerFormState,
  formData: FormData
): Promise<BannerFormState> {
  const session = await verifyAdminSession();
  if (!canWriteCms(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = BulkTogglePositionSchema.safeParse({
    positionCode: formData.get("positionCode"),
    isActive: formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const { positionCode, isActive } = parsed.data;

  const targets = await prisma.banner.findMany({
    where: { positionCode, deletedAt: null },
    select: { id: true, isActive: true },
  });

  if (targets.length === 0) {
    return { error: "해당 위치에 등록된 배너가 없습니다." };
  }

  await prisma.banner.updateMany({
    where: { positionCode, deletedAt: null },
    data: { isActive, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: isActive ? "bulk_activate" : "bulk_deactivate",
      targetType: "banner_position",
      targetId: targets[0].id,
      before: JSON.stringify({
        positionCode,
        affectedIds: targets.map((t) => t.id),
        prevIsActive: targets.map((t) => t.isActive),
      }),
      after: JSON.stringify({ positionCode, isActive, affectedCount: targets.length }),
    },
  });

  revalidatePath("/cms/banners");
  revalidatePath("/dashboard");
  return { success: true };
}
