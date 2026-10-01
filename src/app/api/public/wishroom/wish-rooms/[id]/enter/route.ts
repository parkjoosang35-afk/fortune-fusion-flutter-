// 입장 기록 — Flutter WrRepository.enter() 대응.
// [원본] app/api.js 보조 라우트 · POST /wish-rooms/{id}/enter.
// absentDays>=4이고 아직 알림 안 보냈으면 STATUS(감쇠) 알림 1회 발송.
// absentDays<4면 lastActiveAt을 지금으로 갱신(= 매일 방문하는 동안은 감쇠 없음).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError } from "@/lib/wishroom-engine";
import { createNotification } from "@/lib/notification-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, toWishRoomPublicId } from "../../../_shared";
import { kstDate } from "@/lib/wishroom-engine";

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

      const nowMs = Date.now();
      const before = await buildRoomView(tx, room, auth.userId, nowMs);

      if (before.absentDays >= 4 && !room.decayNotified) {
        await createNotification(tx, {
          userId: auth.userId,
          category: "community",
          title: "소원방 상태 알림",
          body: "소원방 촛불이 조금 약해졌어요. 잠시 들러 돌봐주세요.",
          deepLink: `wishroom:${toWishRoomPublicId(room.id)}`,
        });
        await tx.wishRoom.update({ where: { id: room.id }, data: { decayNotified: true } });
      }

      let updatedRoom = room;
      if (before.absentDays < 4) {
        updatedRoom = await tx.wishRoom.update({
          where: { id: room.id },
          data: { lastActiveAt: new Date(nowMs), decayNotified: false },
          include: { user: { select: { nickname: true } } },
        });
      }

      await tx.wishRoomUserState.upsert({
        where: { userId: auth.userId },
        create: { userId: auth.userId, firstRoomIntroDone: true, lastEnterDate: kstDate(nowMs) },
        update: { firstRoomIntroDone: true, lastEnterDate: kstDate(nowMs) },
      });

      const after = await buildRoomView(tx, updatedRoom, auth.userId, nowMs);
      return { before, room: after, needsRekindle: before.absentDays >= 4 };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
