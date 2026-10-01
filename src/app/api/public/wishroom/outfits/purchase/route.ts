// 의상 구매 — Flutter WrRepository.buyOutfit() 대응. [SERVER] 가격/보유 검증.
// [원본] app/api.js T3 · POST /outfits/purchase { char, theme }.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedCharacterIds, getOwnedOutfits, isAlwaysOwnedCharacter, WishRoomError, WR } from "@/lib/wishroom-engine";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, buildMeView } from "../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { char?: string; theme?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const char = body.char ?? "";
      const theme = body.theme ?? "";
      const price = WR.OUTFIT_PRICE[theme];
      if (price == null) throw new WishRoomError(400, "INVALID", "없는 의상이에요");

      // [캐릭터 보유 확인] F00/M00 등 price===0인 "항상 보유" 캐릭터는 구매 기록 없이도 보유로 취급한다.
      const charDef = WR.CHARACTERS.find((c) => c.id === char);
      let hasChar = !!charDef && isAlwaysOwnedCharacter(charDef);
      if (!hasChar) {
        const ownedChars = await getOwnedCharacterIds(tx, auth.userId);
        hasChar = ownedChars.has(char);
      }
      if (!hasChar) throw new WishRoomError(403, "NO_CHAR", "먼저 캐릭터와 함께해야 해요");

      const hasArt = !!(WR.OUTFIT_ART[char] && WR.OUTFIT_ART[char][theme]);
      if (!hasArt && theme !== "free") throw new WishRoomError(409, "NOT_READY", "이 의상은 아직 준비 중이에요");

      const ownedOutfits = await getOwnedOutfits(tx, auth.userId);
      const key = `${char}:${theme}`;
      if (theme === "free" || ownedOutfits.includes(key)) throw new WishRoomError(409, "OWNED", "이미 가지고 있어요");

      const themeDef = WR.THEMES.find((t) => t.id === theme);
      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount: price,
        sourceType: "wishroom_outfit_purchase",
        memo: `의상 · ${themeDef?.label ?? theme} (${char})`,
      });
      if (!spendResult.ok) throw new WishRoomError(402, "INSUFFICIENT", "복주머니가 부족해요", { need: price, have: spendResult.balanceAfter ?? 0 });

      await tx.wishRoomOutfitOwned.create({ data: { userId: auth.userId, charCode: char, theme, purchasePrice: price } });

      const me = await buildMeView(tx, auth.userId);
      return { me };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
