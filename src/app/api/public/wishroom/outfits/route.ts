// 캐릭터 × 테마 의상 목록 — Flutter WrRepository.outfits() 대응.
// [원본] app/api.js T2 · GET /outfits?char=F03.
// char 쿼리가 없으면 내 대표 캐릭터(WishRoomUserState.repCharCode)를 기본값으로 사용한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedOutfits, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getOrCreateUserState } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const { searchParams } = new URL(request.url);

    const data = await prisma.$transaction(async (tx) => {
      const state = await getOrCreateUserState(tx, auth.userId);
      const ch = searchParams.get("char") || state.repCharCode;
      const ownedOutfits = await getOwnedOutfits(tx, auth.userId);

      return WR.THEMES.map((t) => ({
        char: ch,
        theme: t.id,
        label: t.label,
        glyph: t.glyph,
        price: WR.OUTFIT_PRICE[t.id],
        hasArt: !!(WR.OUTFIT_ART[ch] && WR.OUTFIT_ART[ch][t.id]),
        owned: t.id === "free" || ownedOutfits.includes(`${ch}:${t.id}`),
      }));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
