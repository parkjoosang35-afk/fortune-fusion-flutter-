// 탐색 피드 — Flutter WrRepository.explore() 대응.
// [원본] app/api.js 라우트 8 · GET /wish-rooms/explore.
// PUBLIC만, 내 방 제외, 차단한/당한 사용자 제외, 신고 3회 이상 제외.
// cursor는 lastActiveAt epoch ms(내림차순 페이지네이션, app/api.js는 비페이지네이션
// 전체 목록이었으나 실제 서버에서는 커서 기반으로 확장).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView } from "@/lib/wishroom-engine";
import { requireUser, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getBlockedUserIds } from "../../_shared";

export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const cursor = searchParams.get("cursor");
  const auth = await requireUser(request);

  try {
    const data = await prisma.$transaction(async (tx) => {
      const blocked = auth ? await getBlockedUserIds(tx, auth.userId) : new Set<number>();

      const where: Record<string, unknown> = {
        visibility: "PUBLIC",
        status: { not: "ARCHIVED" },
        deletedAt: null,
        reportCount: { lt: 3 },
      };
      if (auth) where.userId = { not: auth.userId };
      if (cursor) where.lastActiveAt = { lt: new Date(Number(cursor)) };

      const rooms = await tx.wishRoom.findMany({
        where,
        include: { user: { select: { nickname: true } } },
        orderBy: { lastActiveAt: "desc" },
        take: PAGE_SIZE + (blocked.size > 0 ? blocked.size : 0), // 차단 필터링으로 줄어들 수 있는 만큼 여유있게 조회
      });

      const filtered = rooms.filter((r) => !blocked.has(r.userId)).slice(0, PAGE_SIZE);
      const nowMs = Date.now();
      return Promise.all(filtered.map((r) => buildRoomView(tx, r, auth?.userId ?? null, nowMs)));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
