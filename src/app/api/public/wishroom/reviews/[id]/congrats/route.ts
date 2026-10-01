// V5 · POST /reviews/{id}/congrats — ❤ 축하해요 (1인 1회 · 토글, 분당 10회 레이트리밋).
// [원본] app/api.js V5. WishRoomReviewCongrats(reviewId,userId) 유니크 제약으로 1인 1회 보장,
// 이미 있으면 삭제(토글 off), 없으면 생성(토글 on) + congratsCount 증감.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomReviewId, enforceRateLimitAndLog } from "../../../_shared";
import { toReviewDto } from "../../_dto";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomReviewId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "후기 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      await enforceRateLimitAndLog(tx, auth.userId, "review_congrats");

      const review = await tx.wishRoomReview.findUnique({ where: { id: dbId } });
      if (!review || review.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "후기를 찾을 수 없어요");
      if (review.userId === auth.userId) throw new WishRoomError(403, "SELF", "내 이야기에는 축하를 남길 수 없어요");

      const existing = await tx.wishRoomReviewCongrats.findUnique({ where: { reviewId_userId: { reviewId: dbId, userId: auth.userId } } });
      if (existing) {
        await tx.wishRoomReviewCongrats.delete({ where: { id: existing.id } });
        await tx.wishRoomReview.update({ where: { id: dbId }, data: { congratsCount: { decrement: 1 } } });
      } else {
        await tx.wishRoomReviewCongrats.create({ data: { reviewId: dbId, userId: auth.userId } });
        await tx.wishRoomReview.update({ where: { id: dbId }, data: { congratsCount: { increment: 1 } } });
      }

      const updated = await tx.wishRoomReview.findUniqueOrThrow({
        where: { id: dbId },
        include: { user: { select: { nickname: true } }, room: { select: { text: true, wishColor: true } }, congrats: { select: { userId: true } } },
      });
      return toReviewDto(updated, auth.userId);
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
