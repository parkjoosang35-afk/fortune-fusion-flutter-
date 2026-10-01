// 아이템 직접 배치 — Flutter WrRepository.setLayout() 대응.
// [원본] app/api.js 라우트 9' · PATCH /wish-rooms/{id}/layout. 390×844 캔버스 좌표 클램프.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, parseLayout, serializeLayout, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId } from "../../../_shared";

export const dynamic = "force-dynamic";

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { itemId?: string; x?: number; y?: number; s?: number; reset?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 꾸밀 수 있어요");
      if (!body.itemId) throw new WishRoomError(400, "INVALID", "itemId가 필요해요");

      const layout = parseLayout(room.layoutJson);
      if (body.reset) {
        delete layout[body.itemId];
      } else {
        layout[body.itemId] = {
          x: Math.round(clamp(body.x ?? 0, 10, 380)),
          y: Math.round(clamp(body.y ?? 0, 60, 700)),
          s: Math.round(clamp(body.s ?? 52, 24, 160)),
        };
      }

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { layoutJson: serializeLayout(layout) },
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
