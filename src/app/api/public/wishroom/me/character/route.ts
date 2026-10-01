// 대표 캐릭터 변경 — Flutter WrRepository.setCharacter() 대응.
// [원본] app/api.js 17 · PATCH /me/character { id }.
// 보유한 캐릭터만 대표로 설정 가능. 현재 "진행 중"인 소원방(ACTIVE/GROWING/DRAFT)이
// 있으면 그 방의 등장 캐릭터도 함께 바꾼다(app/api.js의 db.myRoomId 단일방 가정을
// "내 소유의 미완료 방 중 가장 최근 것" 기준으로 대응).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOwnedCharacterIds, isAlwaysOwnedCharacter, WishRoomError, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getOrCreateUserState, buildMeView } from "../../_shared";

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { id?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const charId = body.id ?? "";
      const charDef = WR.CHARACTERS.find((c) => c.id === charId);
      let hasChar = !!charDef && isAlwaysOwnedCharacter(charDef);
      if (!hasChar) {
        const owned = await getOwnedCharacterIds(tx, auth.userId);
        hasChar = owned.has(charId);
      }
      if (!hasChar) throw new WishRoomError(403, "NOT_OWNED", "아직 함께하지 않는 캐릭터예요");

      await getOrCreateUserState(tx, auth.userId);
      await tx.wishRoomUserState.update({ where: { userId: auth.userId }, data: { repCharCode: charId } });

      const myRoom = await tx.wishRoom.findFirst({
        where: { userId: auth.userId, status: { in: ["ACTIVE", "GROWING", "DRAFT"] }, deletedAt: null },
      });
      if (myRoom) {
        await tx.wishRoom.update({ where: { id: myRoom.id }, data: { charCode: charId } });
      }

      return buildMeView(tx, auth.userId);
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
