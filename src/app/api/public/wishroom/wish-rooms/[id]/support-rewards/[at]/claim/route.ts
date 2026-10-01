// 응원 보상 마일스톤 수령 — Flutter WrRepository.claimSupportReward() 대응. [SERVER: 응원 수 검증·1회]
// [원본] app/api.js 라우트 R1 · POST /wish-rooms/{id}/support-rewards/{at}/claim.
// item==='RANDOM'(at=50)은 DECORATION 슬롯 중 가격 있고 아직 미보유인 아이템을
// 무작위 지급, 모두 보유 시 +100 복주머니로 대체.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError, WR, getOwnedItemIds } from "@/lib/wishroom-engine";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { createNotification } from "@/lib/notification-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, toWishRoomPublicId, buildMeView } from "../../../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string; at: string }> }) {
  const { id, at: atStr } = await params;
  const dbId = parseWishRoomDbId(id);
  const at = Number(atStr);
  if (dbId === null || !Number.isFinite(at)) {
    return NextResponse.json({ success: false, error: "요청이 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 받을 수 있어요");

      const spec = WR.SUPPORT_REWARDS.find((s) => s.at === at);
      if (!spec) throw new WishRoomError(404, "NOT_FOUND", "없는 보상이에요");
      if (room.supportCount < at) throw new WishRoomError(409, "NOT_YET", `응원 ${at - room.supportCount}회가 더 필요해요`);

      const already = await tx.wishRoomSupportRewardClaim.findUnique({ where: { roomId_at: { roomId: dbId, at } } });
      if (already) throw new WishRoomError(409, "CLAIMED", "이미 받은 보상이에요");

      let itemId: string | null = spec.item;
      let bonus = 0;

      if (itemId === "RANDOM") {
        const owned = await getOwnedItemIds(tx, auth.userId);
        const pool = WR.ITEMS.filter((i) => i.slot === "DECORATION" && i.price && !owned.has(i.id));
        itemId = pool.length ? pool[Math.floor(Math.random() * pool.length)].id : null;
      }

      if (itemId) {
        await tx.wishRoomItemOwned.upsert({
          where: { userId_itemId: { userId: auth.userId, itemId } },
          create: { userId: auth.userId, itemId, purchasePrice: 0 },
          update: {},
        });
      } else {
        bonus = 100;
        await earnLuckPouch(tx, { userId: auth.userId, amount: bonus, sourceType: "wishroom_support_reward", sourceId: room.id, memo: `응원 보상 · 모든 장식 보유 대체 (SUPPORT × ${at})` });
      }

      await tx.wishRoomSupportRewardClaim.create({ data: { roomId: dbId, at, itemCode: itemId } });

      const itemDef = itemId ? WR.ITEMS.find((i) => i.id === itemId) : null;
      await createNotification(tx, {
        userId: auth.userId,
        category: "community",
        title: "응원 보상 도착",
        body: `응원 ${at}회 보상 · ${itemDef ? itemDef.name : `복주머니 ${bonus}`}이(가) 보관함에 담겼어요.`,
        deepLink: `wishroom:${toWishRoomPublicId(room.id)}`,
      });

      const roomView = await buildRoomView(tx, room, auth.userId);
      const me = await buildMeView(tx, auth.userId);
      return {
        room: roomView,
        item: itemDef ? { ...itemDef, owned: true } : null,
        bonus,
        me,
      };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
