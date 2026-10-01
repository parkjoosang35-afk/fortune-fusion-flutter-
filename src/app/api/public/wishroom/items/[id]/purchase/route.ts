// 아이템 구매 — Flutter WrRepository.buyItem() 대응. [SERVER] 가격/보유 검증.
// [원본] app/api.js 14 · POST /items/{id}/purchase.
// price===null인 아이템은 응원 보상(SUPPORT_REWARDS) 전용 — 직접 구매 불가(403 REWARD_ONLY).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedItemIds, isAlwaysOwnedItem, WishRoomError, WR } from "@/lib/wishroom-engine";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, buildMeView } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const item = WR.ITEMS.find((i) => i.id === id);
      if (!item) throw new WishRoomError(404, "NOT_FOUND", "아이템을 찾을 수 없어요");

      if (isAlwaysOwnedItem(item)) throw new WishRoomError(409, "OWNED", "이미 담겨있어요");
      const owned = await getOwnedItemIds(tx, auth.userId);
      if (owned.has(item.id)) throw new WishRoomError(409, "OWNED", "이미 담겨있어요");
      if (item.price == null) throw new WishRoomError(403, "REWARD_ONLY", `응원 ${item.reward}회 보상으로만 받을 수 있어요`);

      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount: item.price,
        sourceType: "wishroom_item_purchase",
        memo: `${item.name} · 꾸미기 · ${item.slot}`,
      });
      if (!spendResult.ok) throw new WishRoomError(402, "INSUFFICIENT", "복주머니가 부족해요", { need: item.price, have: spendResult.balanceAfter ?? 0 });

      await tx.wishRoomItemOwned.create({ data: { userId: auth.userId, itemId: item.id, purchasePrice: item.price } });

      const me = await buildMeView(tx, auth.userId);
      return { item: { ...item, owned: true }, me };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
