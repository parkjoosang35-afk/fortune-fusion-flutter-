"use server";

// 상점 관리 — 쿠폰 관리 Server Actions
// 05_Admin_System_Design.md §3.4 "상점 관리" — 04A J-8/J-9 (coupons, coupon_issues).
// 스펙: "쿠폰 관리 | coupons, coupon_issues CRUD/발급"
// [범위 결정] 원칙⑤(소단위 개발): coupons(마스터) CRUD + 특정 회원에게 coupon_issues
//   발급(단건)까지 이번 소단위에서 다룬다. giftcard_products(J-1) CRUD 패턴과
//   동일한 zod 검증 + RBAC + operation_logs 컨벤션을 따른다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu, canDeleteMenu } from "@/lib/rbac";

function canWriteShop(roleCode: string): boolean {
  return canWriteMenu(roleCode, "shop");
}

function canDeleteShop(roleCode: string): boolean {
  return canDeleteMenu(roleCode, "shop");
}

export interface CouponFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/shop/coupons";

// ══════════════════════════════════════════════════════════
// 04A J-8 coupons
// ══════════════════════════════════════════════════════════
const CouponSchema = z
  .object({
    code: z.string().min(1, "쿠폰 코드를 입력해주세요.").max(30, "쿠폰 코드는 30자 이내여야 합니다."),
    discountType: z.enum(["rate", "fixed_point"]),
    discountValue: z.coerce.number().positive("할인 값은 0보다 커야 합니다."),
    validFrom: z.string().min(1, "유효 시작일을 입력해주세요."),
    validTo: z.string().min(1, "유효 종료일을 입력해주세요."),
    usageLimit: z.coerce.number().int().positive().optional().nullable(),
  })
  .refine((v) => new Date(v.validTo) > new Date(v.validFrom), {
    message: "유효 종료일은 시작일보다 이후여야 합니다.",
    path: ["validTo"],
  });

export async function createCoupon(
  _prevState: CouponFormState,
  formData: FormData
): Promise<CouponFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const usageLimitRaw = formData.get("usageLimit");
  const parsed = CouponSchema.safeParse({
    code: formData.get("code"),
    discountType: formData.get("discountType"),
    discountValue: formData.get("discountValue"),
    validFrom: formData.get("validFrom"),
    validTo: formData.get("validTo"),
    usageLimit: usageLimitRaw === "" ? null : usageLimitRaw,
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { code, discountType, discountValue, validFrom, validTo, usageLimit } = parsed.data;

  const dup = await prisma.coupon.findUnique({ where: { code } });
  if (dup) {
    return { error: "이미 존재하는 쿠폰 코드입니다." };
  }

  const created = await prisma.coupon.create({
    data: {
      code,
      discountType,
      discountValue,
      validFrom: new Date(validFrom),
      validTo: new Date(validTo),
      usageLimit: usageLimit ?? null,
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "coupon",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ code: created.code, discountType, discountValue }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateCouponSchema = z
  .object({
    id: z.coerce.number().int().positive(),
    discountValue: z.coerce.number().positive("할인 값은 0보다 커야 합니다."),
    validFrom: z.string().min(1, "유효 시작일을 입력해주세요."),
    validTo: z.string().min(1, "유효 종료일을 입력해주세요."),
    usageLimit: z.coerce.number().int().positive().optional().nullable(),
  })
  .refine((v) => new Date(v.validTo) > new Date(v.validFrom), {
    message: "유효 종료일은 시작일보다 이후여야 합니다.",
    path: ["validTo"],
  });

export async function updateCoupon(
  _prevState: CouponFormState,
  formData: FormData
): Promise<CouponFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const usageLimitRaw = formData.get("usageLimit");
  const parsed = UpdateCouponSchema.safeParse({
    id: formData.get("id"),
    discountValue: formData.get("discountValue"),
    validFrom: formData.get("validFrom"),
    validTo: formData.get("validTo"),
    usageLimit: usageLimitRaw === "" ? null : usageLimitRaw,
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { id, discountValue, validFrom, validTo, usageLimit } = parsed.data;

  const before = await prisma.coupon.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 쿠폰입니다." };
  }

  // 04A J-8 명시: code는 UQ이며, 이미 발급된 쿠폰의 코드 변경 시 회원 보유 쿠폰과의
  // 정합성 문제가 발생할 수 있어 이번 소단위에서는 code를 수정 불가 필드로 스코프를 정한다.
  const after = await prisma.coupon.update({
    where: { id },
    data: {
      discountValue,
      validFrom: new Date(validFrom),
      validTo: new Date(validTo),
      usageLimit: usageLimit ?? null,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "coupon",
      targetId: id,
      before: JSON.stringify({
        discountValue: before.discountValue,
        validTo: before.validTo,
        usageLimit: before.usageLimit,
      }),
      after: JSON.stringify({
        discountValue: after.discountValue,
        validTo: after.validTo,
        usageLimit: after.usageLimit,
      }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteCouponSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteCoupon(
  _prevState: CouponFormState,
  formData: FormData
): Promise<CouponFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteCouponSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.coupon.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 쿠폰입니다." };
  }

  await prisma.coupon.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "coupon",
      targetId: parsed.data.id,
      before: JSON.stringify({ code: before.code }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 04A J-9 coupon_issues — 회원에게 쿠폰 발급
// ══════════════════════════════════════════════════════════
const IssueCouponSchema = z.object({
  couponId: z.coerce.number().int().positive(),
  userId: z.coerce.number().int().positive("회원을 선택해주세요."),
});

export async function issueCouponToUser(
  _prevState: CouponFormState,
  formData: FormData
): Promise<CouponFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IssueCouponSchema.safeParse({
    couponId: formData.get("couponId"),
    userId: formData.get("userId"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }
  const { couponId, userId } = parsed.data;

  const coupon = await prisma.coupon.findUnique({ where: { id: couponId } });
  if (!coupon || coupon.deletedAt) {
    return { error: "존재하지 않는 쿠폰입니다." };
  }
  if (coupon.validTo < new Date()) {
    return { error: "유효기간이 만료된 쿠폰은 발급할 수 없습니다." };
  }

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    return { error: "존재하지 않는 회원입니다." };
  }

  // 04A J-8 usage_limit: 전체 사용 가능 횟수(발급 수 기준으로 단순화하여 검증).
  if (coupon.usageLimit != null) {
    const issuedCount = await prisma.couponIssue.count({ where: { couponId, deletedAt: null } });
    if (issuedCount >= coupon.usageLimit) {
      return { error: `발급 한도(${coupon.usageLimit}건)를 초과하여 발급할 수 없습니다.` };
    }
  }

  const dupIssue = await prisma.couponIssue.findFirst({
    where: { couponId, userId, deletedAt: null },
  });
  if (dupIssue) {
    return { error: "이미 해당 회원에게 발급된 쿠폰입니다." };
  }

  const created = await prisma.couponIssue.create({
    data: {
      couponId,
      userId,
      status: "unused",
      createdBy: session.email,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "coupon_issue",
      targetType: "coupon_issue",
      targetId: created.id,
      before: null,
      after: JSON.stringify({ couponId, userId, couponCode: coupon.code }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
