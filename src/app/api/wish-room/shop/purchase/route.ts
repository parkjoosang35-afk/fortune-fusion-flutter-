// 공개(비인증) 소원방 상점 구매 API — 테마(theme)/오브젝트(object) 공용 구매 엔드포인트.
//
// [절대 원칙] 복주머니 차감은 서버가 확정한다(spendLuckPouch). 클라이언트가 가격을
// 보내더라도 서버는 WishRoomTheme/WishRoomObject.pouchPrice를 다시 조회해 사용하며,
// 클라이언트 값은 신뢰하지 않는다. 동일 requestId 재요청은 중복 차감하지 않는다
// (WishRoomInventory.requestId unique). 이미 보유한 아이템은 재구매를 막는다
// (WishRoomInventory의 (userId, itemType, itemId) unique 제약).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { CORS_HEADERS, corsOptionsResponse } from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface PurchaseBody {
  userId?: number;
  itemType?: string; // "theme" | "object"
  itemId?: number;
  requestId?: string;
}

export async function POST(request: NextRequest) {
  let body: PurchaseBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  const userId = Number(body.userId ?? 1);
  const itemType = body.itemType;
  const itemId = Number(body.itemId);
  const requestId = body.requestId;

  if (itemType !== "theme" && itemType !== "object") {
    return NextResponse.json({ success: false, error: "itemType은 theme 또는 object여야 합니다." }, { status: 400, headers: CORS_HEADERS });
  }
  if (!Number.isInteger(itemId)) {
    return NextResponse.json({ success: false, error: "itemId가 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    // 1) idempotency — 동일 requestId로 이미 처리된 요청이면 그대로 반환.
    if (requestId) {
      const existing = await prisma.wishRoomInventory.findUnique({ where: { requestId } });
      if (existing) {
        const wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
        return NextResponse.json(
          {
            success: true,
            idempotent: true,
            data: { inventoryId: existing.id, itemType: existing.itemType, itemId: existing.itemId, balance: wallet?.balance ?? null },
          },
          { headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      // 2) 이미 보유 중인지 확인(회원간 격리 — userId로 항상 필터링).
      const owned = await tx.wishRoomInventory.findUnique({
        where: { userId_itemType_itemId: { userId, itemType, itemId } },
      });
      if (owned) throw new Error("ALREADY_OWNED");

      // 3) 아이템 마스터 조회 — 가격은 항상 서버가 재조회한 값을 사용한다.
      let price: number;
      let isPurchasable: boolean;
      let isActive: boolean;
      if (itemType === "theme") {
        const theme = await tx.wishRoomTheme.findUnique({ where: { id: itemId } });
        if (!theme || theme.deletedAt) throw new Error("ITEM_NOT_FOUND");
        price = theme.pouchPrice;
        isPurchasable = theme.isPurchasable;
        isActive = theme.isActive;
      } else {
        const obj = await tx.wishRoomObject.findUnique({ where: { id: itemId } });
        if (!obj || obj.deletedAt) throw new Error("ITEM_NOT_FOUND");
        price = obj.pouchPrice;
        isPurchasable = obj.unlockType === "purchase";
        isActive = obj.isActive;
      }
      if (!isActive) throw new Error("ITEM_NOT_FOUND");
      if (!isPurchasable) throw new Error("NOT_PURCHASABLE");

      // 4) 복주머니 차감(서버 확정). 잔액 부족 시 INSUFFICIENT_BALANCE.
      const spendOutcome = await spendLuckPouch(tx, {
        userId,
        amount: price,
        sourceType: `wish_room_shop_${itemType}`,
        sourceId: itemId,
        memo: `소원방 상점 구매(${itemType}#${itemId})`,
      });
      if (!spendOutcome.ok) throw new Error("INSUFFICIENT_BALANCE");

      const inventory = await tx.wishRoomInventory.create({
        data: { userId, itemType, itemId, acquiredVia: "purchase", requestId: requestId ?? null },
      });

      return { inventory, balance: spendOutcome.balanceAfter, price };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          inventoryId: result.inventory.id,
          itemType: result.inventory.itemType,
          itemId: result.inventory.itemId,
          price: result.price,
          balance: result.balance,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "ITEM_NOT_FOUND") {
      return NextResponse.json({ success: false, error: "구매할 수 없는 아이템입니다." }, { status: 404, headers: CORS_HEADERS });
    }
    if (message === "ALREADY_OWNED") {
      return NextResponse.json({ success: false, error: "이미 보유한 아이템입니다.", reason: "ALREADY_OWNED" }, { status: 409, headers: CORS_HEADERS });
    }
    if (message === "NOT_PURCHASABLE") {
      return NextResponse.json({ success: false, error: "구매로 획득할 수 없는 아이템입니다.", reason: "NOT_PURCHASABLE" }, { status: 409, headers: CORS_HEADERS });
    }
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json({ success: false, error: "복주머니가 부족합니다.", reason: "INSUFFICIENT_BALANCE" }, { status: 409, headers: CORS_HEADERS });
    }
    console.error("[POST /api/wish-room/shop/purchase] 실패:", e);
    return NextResponse.json({ success: false, error: "구매 처리에 실패했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
