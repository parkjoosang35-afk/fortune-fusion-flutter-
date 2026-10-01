// 캐릭터 카탈로그 — Flutter WrRepository.characters() 대응.
// [원본] app/api.js 15 · GET /characters.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedCharacterIds, isAlwaysOwnedCharacter, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const owned = await getOwnedCharacterIds(tx, auth.userId);
      return WR.CHARACTERS.map((c) => ({ ...c, owned: isAlwaysOwnedCharacter(c) || owned.has(c.id) }));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
