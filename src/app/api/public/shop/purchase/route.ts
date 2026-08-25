// 상점 구매 API — bokjumeoni-plan §03 SERVER API `POST /shop/purchase` 대응.
//
// body: { itemType: "seal"|"candle"|"talisman", itemCode: string }
//
// [절대 원칙 — Prisma Transaction 강제] 잔액 차감(spendLuckPouch) + 인벤토리
// 추가(UserInventoryItem.create)를 반드시 하나의 $transaction으로 처리한다.
// 하나라도 실패하면 전체 롤백되어야 한다(예: 인벤토리 생성 실패 시 이미
// 차감된 복주머니가 그대로 남는 일이 없어야 함).
//
// [가격 신뢰 원칙] 클라이언트가 price를 보내지 않는다 — 반드시 서버가
// ShopCatalogItem.price를 다시 조회해서 그 값으로만 차감한다(클라이언트
// 조작 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { CORS_HEADERS, isShopItemType, toInventoryItemDto } from "../_shared";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { itemType?: string; itemCode?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const itemType = body.itemType;
  const itemCode = (body.itemCode ?? "").trim();
  if (!isShopItemType(itemType) || !itemCode) {
    return NextResponse.json(
      { success: false, error: "itemType, itemCode는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const catalogItem = await tx.shopCatalogItem.findUnique({ where: { itemCode } });
      if (!catalogItem || catalogItem.deletedAt != null) {
        throw new Error("ITEM_NOT_FOUND");
      }
      if (catalogItem.itemType !== itemType) {
        throw new Error("ITEM_TYPE_MISMATCH");
      }
      if (!catalogItem.isActive) {
        throw new Error("ITEM_INACTIVE");
      }

      // [가격 신뢰 원칙] 서버가 다시 조회한 catalogItem.price로만 차감한다.
      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount: catalogItem.price,
        sourceType: "shop_purchase",
        sourceId: catalogItem.id,
        memo: `상점 구매: ${catalogItem.nameKo}`,
      });
      if (!spendResult.ok) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      const expiresAt = catalogItem.durationDays
        ? new Date(Date.now() + catalogItem.durationDays * 24 * 60 * 60 * 1000)
        : null;

      const inventoryItem = await tx.userInventoryItem.create({
        data: {
          userId: auth.userId,
          catalogItemId: catalogItem.id,
          purchasePrice: catalogItem.price,
          expiresAt,
        },
        include: { catalogItem: true },
      });

      return { inventoryItem, balanceAfter: spendResult.balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          ...toInventoryItemDto(result.inventoryItem),
          walletBalanceAfter: result.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "ITEM_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 상품입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "ITEM_TYPE_MISMATCH") {
      return NextResponse.json(
        { success: false, error: "상품 분류가 일치하지 않습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    if (message === "ITEM_INACTIVE") {
      return NextResponse.json(
        { success: false, error: "지금은 판매하지 않는 상품입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json(
        { success: false, error: "복주머니가 부족합니다.", reason: "INSUFFICIENT_BALANCE" },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/shop/purchase] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구매 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
