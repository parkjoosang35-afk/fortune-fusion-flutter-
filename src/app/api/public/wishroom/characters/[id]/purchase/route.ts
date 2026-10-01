// 캐릭터 구매 — Flutter WrRepository.buyCharacter() 대응. [SERVER] 가격/등급 검증.
// [원본] app/api.js 16 · POST /characters/{id}/purchase.
// grade==='event'인 캐릭터는 이벤트 미션 전용 — 직접 구매 불가(403 EVENT_ONLY).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedCharacterIds, isAlwaysOwnedCharacter, WishRoomError, WR } from "@/lib/wishroom-engine";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, buildMeView } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const char = WR.CHARACTERS.find((c) => c.id === id);
      if (!char) throw new WishRoomError(404, "NOT_FOUND", "캐릭터를 찾을 수 없어요");

      if (isAlwaysOwnedCharacter(char)) throw new WishRoomError(409, "OWNED", "이미 함께하고 있어요");
      const owned = await getOwnedCharacterIds(tx, auth.userId);
      if (owned.has(char.id)) throw new WishRoomError(409, "OWNED", "이미 함께하고 있어요");
      if (char.grade === "event") throw new WishRoomError(403, "EVENT_ONLY", "이벤트 미션으로만 만날 수 있어요");

      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount: char.price,
        sourceType: "wishroom_character_purchase",
        memo: `${char.name} · ${char.title}`,
      });
      if (!spendResult.ok) throw new WishRoomError(402, "INSUFFICIENT", "복주머니가 부족해요", { need: char.price, have: spendResult.balanceAfter ?? 0 });

      await tx.wishRoomCharacterOwned.create({ data: { userId: auth.userId, charCode: char.id, purchasePrice: char.price } });

      const me = await buildMeView(tx, auth.userId);
      return { character: { ...char, owned: true }, me };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
