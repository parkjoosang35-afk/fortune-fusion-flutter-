// 완료 선언 / 취소(7일 이내) — Flutter WrRepository.complete() 대응.
// [원본] app/api.js 10 · POST /wish-rooms/{id}/complete { cancel? }.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError } from "@/lib/wishroom-engine";
import { createNotification } from "@/lib/notification-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, toWishRoomPublicId } from "../../../_shared";

export const dynamic = "force-dynamic";
const DAY_MS = 86400000;

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { cancel?: boolean };
  try {
    body = await request.json().catch(() => ({}));
  } catch {
    body = {};
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 선언할 수 있어요");

      if (body.cancel) {
        if (room.status !== "COMPLETED") throw new WishRoomError(409, "INVALID_STATE", "완료 상태가 아니에요");
        if (!room.completedAt || Date.now() > room.completedAt.getTime() + 7 * DAY_MS) {
          throw new WishRoomError(409, "CANCEL_EXPIRED", "완료 후 7일이 지나 취소할 수 없어요");
        }
        if (room.reviewRewardGranted) throw new WishRoomError(409, "REVIEWED", "후기를 남긴 소원은 되돌릴 수 없어요");

        const newStatus = room.devotionCount + room.supportCount > 0 ? "GROWING" : "ACTIVE";
        const updated = await tx.wishRoom.update({
          where: { id: dbId },
          data: { status: newStatus, completedAt: null, wishStatus: "IN_PROGRESS" },
          include: { user: { select: { nickname: true } } },
        });
        return buildRoomView(tx, updated, auth.userId);
      }

      if (!["ACTIVE", "GROWING"].includes(room.status)) throw new WishRoomError(409, "INVALID_STATE", "이미 완료된 소원이에요");

      const nowDate = new Date();
      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { status: "COMPLETED", completedAt: nowDate, wishStatus: "ACHIEVED" },
        include: { user: { select: { nickname: true } } },
      });

      await createNotification(tx, {
        userId: auth.userId,
        category: "community",
        title: "소중한 소원이 이루어졌어요.",
        body: "소중한 소원이 이루어졌어요.",
        deepLink: `wishroom:${toWishRoomPublicId(dbId)}`,
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
