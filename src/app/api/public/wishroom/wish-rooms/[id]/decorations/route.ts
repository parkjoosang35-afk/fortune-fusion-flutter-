// 꾸미기(아이템 장착/해제) — Flutter WrRepository.equip() 대응. [SERVER] 슬롯 규칙.
// [원본] app/api.js 라우트 9 · PATCH /wish-rooms/{id}/decorations.
// max=1 슬롯은 단일 교체, max>1 슬롯(DECORATION/SEAL/THEME)은 토글(이미 있으면 제거,
// 없으면 추가하되 SLOT_FULL 체크). freeTier 아닌 아이템은 보유해야 장착 가능.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, getOwnedItemIds, isAlwaysOwnedItem, parseEquip, serializeEquip, WishRoomError, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { itemId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 꾸밀 수 있어요");
      if (["SEALED", "ARCHIVED"].includes(room.status)) throw new WishRoomError(409, "READ_ONLY", "봉인된 소원방은 바꿀 수 없어요");

      const item = WR.ITEMS.find((i) => i.id === body.itemId);
      if (!item) throw new WishRoomError(404, "NOT_FOUND", "아이템을 찾을 수 없어요");

      if (!isAlwaysOwnedItem(item)) {
        const owned = await getOwnedItemIds(tx, auth.userId);
        if (!owned.has(item.id)) throw new WishRoomError(402, "NOT_OWNED", "아직 담지 않은 아이템이에요");
      }

      const slot = WR.SLOTS.find((s) => s.id === item.slot);
      if (!slot) throw new WishRoomError(400, "INVALID", "알 수 없는 슬롯이에요");

      const equip = parseEquip(room.equipJson);
      const layout = JSON.parse(room.layoutJson || "{}") as Record<string, unknown>;

      if (slot.max > 1) {
        const key = slot.id as "DECORATION" | "SEAL" | "THEME";
        const arr = equip[key] ?? [];
        if (arr.includes(item.id)) {
          equip[key] = arr.filter((x) => x !== item.id);
          delete layout[item.id];
        } else {
          if (arr.length >= slot.max) throw new WishRoomError(409, "SLOT_FULL", `${slot.label}은(는) 최대 ${slot.max}개까지 놓을 수 있어요`);
          equip[key] = [...arr, item.id];
        }
      } else if (slot.id === "CANDLE" || slot.id === "FLOWER" || slot.id === "BACKGROUND" || slot.id === "SPECIAL") {
        equip[slot.id] = item.id;
      }

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { equipJson: serializeEquip(equip), layoutJson: JSON.stringify(layout) },
        include: { user: { select: { nickname: true } } },
      });
      return buildRoomView(tx, updated, auth.userId);
    });

    return NextResponse.json({ success: true, data: view }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
