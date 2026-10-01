// 소원 종이 색 변경 — Flutter WrRepository.setPaper() 대응.
// [원본] app/api.js 9'' · PATCH /wish-rooms/{id}/paper { paper }.
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

  let body: { paper?: string };
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
      if (!WR.PAPERS.find((p) => p.id === body.paper)) throw new WishRoomError(400, "INVALID", "없는 종이 색이에요");

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { paper: body.paper! },
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
