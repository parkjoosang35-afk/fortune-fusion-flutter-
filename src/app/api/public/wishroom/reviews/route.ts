// V4 · GET /reviews?mine=1 — 「소원이 이루어진 이야기」 피드(공개+정상) / 내 후기 목록.
// [원본] app/api.js V4. mine=1이면 내 후기 전체(상태 무관), 아니면 PUBLIC+visible+차단되지 않은
// 작성자만. 비로그인도 공개 피드는 조회 가능(mine은 인증 필요).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getBlockedUserIds } from "../_shared";
import { toReviewDto } from "./_dto";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const mine = searchParams.get("mine") === "1";
  const auth = await requireUser(request);

  try {
    const data = await prisma.$transaction(async (tx) => {
      if (mine) {
        if (!auth) throw new WishRoomError(401, "UNAUTHORIZED", "로그인이 필요해요");
        const rows = await tx.wishRoomReview.findMany({
          where: { userId: auth.userId, deletedAt: null },
          include: { user: { select: { nickname: true } }, room: { select: { text: true, wishColor: true } }, congrats: { select: { userId: true } } },
          orderBy: { createdAt: "desc" },
        });
        return rows.map((r) => toReviewDto(r, auth.userId));
      }

      const blocked = auth ? await getBlockedUserIds(tx, auth.userId) : new Set<number>();
      const rows = await tx.wishRoomReview.findMany({
        where: { visibility: "PUBLIC", status: "visible", deletedAt: null },
        include: { user: { select: { nickname: true } }, room: { select: { text: true, wishColor: true } }, congrats: { select: { userId: true } } },
        orderBy: { createdAt: "desc" },
        take: 100,
      });
      return rows.filter((r) => !blocked.has(r.userId)).map((r) => toReviewDto(r, auth?.userId ?? null));
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
