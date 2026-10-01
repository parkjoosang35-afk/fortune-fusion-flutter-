// 공유 링크로 들어온 사람의 방 조회 — Flutter WrRepository.roomByToken() 대응.
// [원본] app/api.js S2 · GET /share/{token}. LINK·PUBLIC 허용, PRIVATE·무효 토큰은 404.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const auth = await requireUser(request);

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { shareToken: token }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null || room.visibility === "PRIVATE") {
        throw new WishRoomError(404, "LINK_INVALID", "더 이상 열 수 없는 링크예요");
      }
      return buildRoomView(tx, room, auth?.userId ?? null);
    });

    return NextResponse.json({ success: true, data: view }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
