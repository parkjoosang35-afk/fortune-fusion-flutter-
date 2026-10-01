// 응원 — Flutter WrRepository.support() 대응. [SERVER] 1인 1방 1일 1회, 자기 방 불가.
// [원본] app/api.js 라우트 5 · POST /wish-rooms/{id}/supports.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, calcPoints, kstDate, levelOf, WishRoomError, WR } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, enforceRateLimitAndLog } from "../../../_shared";

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
      await enforceRateLimitAndLog(tx, auth.userId, "support");

      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId === auth.userId) throw new WishRoomError(403, "SELF", "내 소원방에는 응원할 수 없어요");

      const nowMs = Date.now();
      const today = kstDate(nowMs);

      const existing = await tx.wishRoomSupport.findUnique({
        where: { roomId_userId_dateKey: { roomId: dbId, userId: auth.userId, dateKey: today } },
      });
      if (existing) throw new WishRoomError(409, "ALREADY", "오늘은 이미 응원했어요");

      await tx.wishRoomSupport.create({ data: { roomId: dbId, userId: auth.userId, dateKey: today } });

      const newSupportCount = room.supportCount + 1;
      const newPoints = calcPoints({ devotionCount: room.devotionCount, supportCount: newSupportCount, pouchReceived: room.pouchReceived, bonusPts: room.bonusPts });
      const newLevel = levelOf(newPoints);

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { supportCount: newSupportCount, points: newPoints, level: newLevel },
        include: { user: { select: { nickname: true } } },
      });

      const reward = WR.SUPPORT_REWARDS.find((s) => s.at === newSupportCount) ?? null;
      const roomView = await buildRoomView(tx, updated, auth.userId, nowMs);
      return { room: roomView, reward };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
