"use server";

// 상점 관리 — 상품권 상품 관리 Server Actions
// 05_Admin_System_Design.md §3.4 "상점 관리" — 04A J-1 giftcard_products.
// [범위 결정] 원칙⑤(소단위 개발)에 따라 이번 소단위는 상품(재고 포함) CRUD까지만 다룬다.
//   giftcard_issues~expiry_logs(J-2~J-7 생명주기)와 coupons/coupon_issues(J-8/J-9)는
//   다음 소단위에서 순서대로 추가한다.
// 05§1 원칙2: 모든 CUD 작업은 예외 없이 operation_logs 기록.
// 04A J-1 명시: stock_count CHECK(stock_count>=0), "원자적 감소 대상"이라는 설명은
//   실제 발급(J-2) 처리 시 트랜잭션으로 감소시키는 로직에 적용될 원칙이며, 이번
//   상품 관리 화면에서는 관리자가 재고 수량을 직접 설정/조정하는 것으로 스코프를 정한다.
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

export interface GiftcardFormState {
  error?: string;
  success?: boolean;
}

const REVALIDATE_PATH = "/shop/giftcards";

// ══════════════════════════════════════════════════════════
// 04A J-1 giftcard_products
// ══════════════════════════════════════════════════════════
const GiftcardProductSchema = z.object({
  name: z.string().min(1, "상품명을 입력해주세요."),
  brand: z.string().min(1, "브랜드를 입력해주세요."),
  requiredPoint: z.coerce.number().int().min(0, "필요 포인트는 0 이상이어야 합니다."),
  stockCount: z.coerce.number().int().min(0, "재고는 0 이상이어야 합니다."),
  validDays: z.coerce.number().int().min(1, "유효기간은 1일 이상이어야 합니다.").optional().default(365),
  imageUrl: z.string().optional().nullable(),
  isActive: z.coerce.boolean().optional().default(true),
});

export async function createGiftcardProduct(
  _prevState: GiftcardFormState,
  formData: FormData
): Promise<GiftcardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const parsed = GiftcardProductSchema.safeParse({
    name: formData.get("name"),
    brand: formData.get("brand"),
    requiredPoint: formData.get("requiredPoint"),
    stockCount: formData.get("stockCount"),
    validDays: formData.get("validDays"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const created = await prisma.giftcardProduct.create({
    data: { ...parsed.data, createdBy: session.email, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "create",
      targetType: "giftcard_product",
      targetId: created.id,
      before: null,
      after: JSON.stringify({
        name: created.name,
        brand: created.brand,
        requiredPoint: created.requiredPoint,
        stockCount: created.stockCount,
      }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const UpdateGiftcardProductSchema = GiftcardProductSchema.extend({
  id: z.coerce.number().int().positive(),
});

export async function updateGiftcardProduct(
  _prevState: GiftcardFormState,
  formData: FormData
): Promise<GiftcardFormState> {
  const session = await verifyAdminSession();
  if (!canWriteShop(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const imageUrlRaw = formData.get("imageUrl");
  const parsed = UpdateGiftcardProductSchema.safeParse({
    id: formData.get("id"),
    name: formData.get("name"),
    brand: formData.get("brand"),
    requiredPoint: formData.get("requiredPoint"),
    stockCount: formData.get("stockCount"),
    validDays: formData.get("validDays"),
    imageUrl: imageUrlRaw === "" ? null : imageUrlRaw,
    isActive: formData.get("isActive") === "on" || formData.get("isActive") === "true",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, ...data } = parsed.data;
  const before = await prisma.giftcardProduct.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 상품권 상품입니다." };
  }

  const after = await prisma.giftcardProduct.update({
    where: { id },
    data: { ...data, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "giftcard_product",
      targetId: id,
      before: JSON.stringify({
        name: before.name,
        requiredPoint: before.requiredPoint,
        stockCount: before.stockCount,
      }),
      after: JSON.stringify({
        name: after.name,
        requiredPoint: after.requiredPoint,
        stockCount: after.stockCount,
      }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}

const DeleteGiftcardProductSchema = z.object({ id: z.coerce.number().int().positive() });

export async function deleteGiftcardProduct(
  _prevState: GiftcardFormState,
  formData: FormData
): Promise<GiftcardFormState> {
  const session = await verifyAdminSession();
  if (!canDeleteShop(session.roleCode)) {
    return { error: "삭제 권한은 super_admin만 보유합니다." };
  }

  const parsed = DeleteGiftcardProductSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }

  const before = await prisma.giftcardProduct.findUnique({ where: { id: parsed.data.id } });
  if (!before) {
    return { error: "존재하지 않는 상품권 상품입니다." };
  }

  await prisma.giftcardProduct.update({
    where: { id: parsed.data.id },
    data: { deletedAt: new Date(), status: "deleted", isActive: false, updatedBy: session.email },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "delete",
      targetType: "giftcard_product",
      targetId: parsed.data.id,
      before: JSON.stringify({ name: before.name }),
      after: JSON.stringify({ status: "deleted" }),
    },
  });

  revalidatePath(REVALIDATE_PATH);
  return { success: true };
}
