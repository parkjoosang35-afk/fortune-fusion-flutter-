// 봉인 → 스냅샷 보관 → ARCHIVED — Flutter WrRepository.seal() 대응.
// [원본] app/api.js 11 · POST /wish-rooms/{id}/seal.
// COMPLETED 상태에서만 가능. 마지막 상태(꾸미기/레벨/정성 등)를 JSON 스냅샷으로
// 동결하고(이후 ARCHIVED 상태에서 방이 더 바뀌어도 보관함 열람은 스냅샷 기준),
// 상태를 SEALED를 거쳐 즉시 ARCHIVED로 전환한다(app/api.js §4 봉인 직후 자동 전환).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId } from "../../../_shared";

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

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 봉인할 수 있어요");
      if (room.status !== "COMPLETED") throw new WishRoomError(409, "INVALID_STATE", "먼저 소원이 이루어졌음을 알려주세요");

      const sealedAt = new Date();
      const days = room.completedAt ? Math.max(1, Math.round((sealedAt.getTime() - room.createdAt.getTime()) / DAY_MS)) : 1;
      const snapshot = {
        text: room.text,
        char: room.charCode,
        equip: JSON.parse(room.equipJson || "{}"),
        layout: JSON.parse(room.layoutJson || "{}"),
        wishColor: room.wishColor,
        paper: room.paper,
        level: room.level,
        supportCount: room.supportCount,
        pouchReceived: room.pouchReceived,
        devotionCount: room.devotionCount,
        createdAt: room.createdAt.getTime(),
        completedAt: room.completedAt ? room.completedAt.getTime() : null,
        sealedAt: sealedAt.getTime(),
        days,
      };

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { sealedAt, snapshot: JSON.stringify(snapshot), status: "ARCHIVED" },
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
