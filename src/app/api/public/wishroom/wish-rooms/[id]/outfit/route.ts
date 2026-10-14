// 방에서 캐릭터가 입을 의상 설정 — Flutter WrRepository.setOutfit() 대응.
// [원본] app/api.js T4 · PATCH /wish-rooms/{id}/outfit { theme | null }.
// theme=null 이면 방 테마(room.theme)를 그대로 따라간다(roomView의 outfitNowOf 계산).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, getOwnedOutfits, WishRoomError, namedOutfitFor, WR } from "@/lib/wishroom-engine";
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

  let body: { theme?: string | null; outfitId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 바꿀 수 있어요");

      if (['SEALED', 'ARCHIVED'].includes(room.status)) throw new WishRoomError(409, 'READ_ONLY', '보관된 방은 바꿀 수 없어요');
      const named = body.outfitId ? namedOutfitFor(room.charCode, body.outfitId) : null;
      if (body.outfitId && !named) throw new WishRoomError(403, 'INCOMPATIBLE', '하린·준 전용 의상이에요');
      const theme = named?.id ?? body.theme ?? null;
      if (theme && !named && !WR.THEMES.some((t) => t.id === theme)) throw new WishRoomError(400, 'INVALID', '없는 의상이에요');
      if (named && named.theme !== room.theme) throw new WishRoomError(409, 'THEME_MISMATCH', '소원방 테마에 맞는 의상을 선택해 주세요');
      if (theme && theme !== "free") {
        const ownedOutfits = await getOwnedOutfits(tx, auth.userId);
        if (!ownedOutfits.includes(`${room.charCode}:${theme}`)) {
          throw new WishRoomError(402, "NOT_OWNED", "아직 없는 의상이에요");
        }
      }

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { outfit: theme },
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
