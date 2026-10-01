// 촛불 다시 밝히기 — Flutter WrRepository.rekindle() 대응.
// [원본] app/api.js 보조 라우트 · POST /wish-rooms/{id}/rekindle.
// 4일 이상 부재가 아니면 409 NOT_DIM(이미 밝게 타고 있음). 방 주인만 가능.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 촛불을 밝힐 수 있어요");

      const nowMs = Date.now();
      const before = await buildRoomView(tx, room, auth.userId, nowMs);
      if (before.absentDays < 4) throw new WishRoomError(409, "NOT_DIM", "촛불이 이미 밝게 타고 있어요");

      const updated = await tx.wishRoom.update({
        where: { id: room.id },
        data: { lastActiveAt: new Date(nowMs), decayNotified: false },
        include: { user: { select: { nickname: true } } },
      });
      const after = await buildRoomView(tx, updated, auth.userId, nowMs);
      return { before, room: after, absentDays: before.absentDays };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
