// 타임캡슐 열기 — Flutter WrRepository.unseal() 대응. [SERVER] 날짜 검증.
// [원본] app/api.js C1 · POST /wish-rooms/{id}/unseal.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, dayDiff, kstDate, WishRoomError } from "@/lib/wishroom-engine";
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
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 열 수 있어요");
      if (!room.sealUntil) throw new WishRoomError(409, "NO_CAPSULE", "봉인된 소원이 아니에요");

      const today = kstDate();
      const diff = dayDiff(today, room.sealUntil);
      if (diff > 0) throw new WishRoomError(409, "NOT_YET", `아직 봉인 중이에요 · D-${diff}`);

      const nowDate = new Date();
      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { capsule: "OPENED", lastActiveAt: nowDate },
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
