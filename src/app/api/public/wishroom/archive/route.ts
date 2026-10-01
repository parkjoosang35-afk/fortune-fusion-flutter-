// 내 보관함(ARCHIVED 소원방) 목록 — Flutter WrRepository.archive() 대응.
// [원본] app/api.js 12 · GET /archive.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const rooms = await tx.wishRoom.findMany({
        where: { userId: auth.userId, status: "ARCHIVED", deletedAt: null },
        include: { user: { select: { nickname: true } } },
        orderBy: { sealedAt: "desc" },
      });
      return Promise.all(rooms.map((r) => buildRoomView(tx, r, auth.userId)));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
