// 내 소원방 조회 — Flutter WrRepository.myRoom() 대응.
// [원본] app/api.js 라우트 2 · GET /wish-rooms/me.
// - 방이 없거나 ARCHIVED면 room=null.
// - 봉인일 도착 && capsule=LOCKED && 아직 알림 안 보냈으면 UNSEAL 알림 1회 발송.
// - introMode: 최초 1회 'full', skipIntro면 'none', 오늘 처음 들어왔으면 'short'.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, dayDiff, kstDate } from "@/lib/wishroom-engine";
import { createNotification } from "@/lib/notification-engine";
import { buildMeView, getOrCreateUserState, requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, wrNotificationDeepLink } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findFirst({
        where: { userId: auth.userId, status: { not: "ARCHIVED" }, deletedAt: null },
        include: { user: { select: { nickname: true } } },
      });

      const nowMs = Date.now();
      const today = kstDate(nowMs);

      if (room && room.sealUntil && room.capsule === "LOCKED" && !room.unsealNotified && dayDiff(today, room.sealUntil) <= 0) {
        await createNotification(tx, {
          userId: auth.userId,
          category: "community",
          title: "소원 봉인 해제",
          body: "🎁 소원 봉인이 풀렸습니다. 예전에 내가 빌었던 소원을 다시 확인해보세요.",
          deepLink: wrNotificationDeepLink(room.id, "UNSEAL"),
        });
        await tx.wishRoom.update({ where: { id: room.id }, data: { unsealNotified: true } });
      }

      const state = await getOrCreateUserState(tx, auth.userId);
      let introMode: "full" | "short" | "none" = "none";
      if (room) {
        if (!state.firstRoomIntroDone) introMode = "full";
        else if (state.skipIntro) introMode = "none";
        else if (state.lastEnterDate !== today) introMode = "short";
      }

      const roomView = room ? await buildRoomView(tx, room, auth.userId, nowMs) : null;
      const me = await buildMeView(tx, auth.userId, nowMs);

      return { room: roomView, me, introMode };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
