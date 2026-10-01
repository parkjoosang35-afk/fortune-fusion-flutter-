// V6 · POST /reviews/{id}/report — 신고(3회 누적 자동 숨김, 관리자 검토 큐 등록).
// [원본] app/api.js V6. reports/route.ts(roomId/commentId 전용)와는 별도 네임스페이스
// (targetType: "wish_room_review") — 공용 reports 테이블에도 함께 기록한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomReviewId } from "../../../_shared";

export const dynamic = "force-dynamic";

const HIDE_THRESHOLD = 3;

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomReviewId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "후기 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { reason?: string };
  try {
    body = await request.json().catch(() => ({}));
  } catch {
    body = {};
  }
  const reason = (body.reason ?? "").trim() || "기타";

  try {
    await prisma.$transaction(async (tx) => {
      const review = await tx.wishRoomReview.findUnique({ where: { id: dbId } });
      if (!review || review.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "후기를 찾을 수 없어요");

      const newCount = review.reportCount + 1;
      await tx.wishRoomReview.update({
        where: { id: dbId },
        data: { reportCount: newCount, status: newCount >= HIDE_THRESHOLD ? "hidden_by_report" : review.status },
      });
      await tx.report.create({
        data: { targetType: "wish_room_review", targetId: dbId, reporterId: auth.userId, reason },
      });
    });

    return NextResponse.json({ success: true, data: { ok: true } }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
