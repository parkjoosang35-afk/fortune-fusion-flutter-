// 소원방 테마 변경 — Flutter WrRepository.setTheme() 대응.
// [원본] app/api.js T1 · PATCH /wish-rooms/{id}/theme { theme }.
// 방 의상이 테마를 따라가는 경우(outfit=null) 테마 변경만으로 자동 반영되므로
// (roomView의 outfitNowOf 계산이 room.outfit ?? room.theme 순으로 처리)
// 이 라우트는 theme 컬럼만 바꾸면 된다 — outfit 컬럼은 건드리지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError, WR } from "@/lib/wishroom-engine";
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

  let body: { theme?: string };
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
      if (["SEALED", "ARCHIVED"].includes(room.status)) throw new WishRoomError(409, "READ_ONLY", "봉인된 소원방은 바꿀 수 없어요");
      if (!WR.THEMES.some((t) => t.id === body.theme)) throw new WishRoomError(400, "INVALID", "없는 테마예요");

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { theme: body.theme! },
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
