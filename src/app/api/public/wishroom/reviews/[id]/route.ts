// V2 · PATCH /reviews/{id} — 후기 수정(보상 재지급 없음). V3 · DELETE /reviews/{id} — 삭제(지급된 보상 회수 안 함).
// [원본] app/api.js V2/V3.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { filterText, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomReviewId } from "../../_shared";
import { toReviewDto } from "../_dto";

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomReviewId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "후기 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { text?: string; photo?: string; visibility?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const review = await tx.wishRoomReview.findUnique({ where: { id: dbId } });
      if (!review || review.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "후기를 찾을 수 없어요");
      if (review.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "내 후기만 고칠 수 있어요");

      const update: { text?: string; photoUrl?: string | null; visibility?: string } = {};
      if (body.text != null) {
        const t = body.text.trim();
        if (t.replace(/\s/g, "").length < 20) throw new WishRoomError(400, "TOO_SHORT", "20자 이상 적어주세요");
        filterText(t, true);
        update.text = t;
      }
      if (body.photo !== undefined) update.photoUrl = body.photo;
      if (body.visibility) update.visibility = body.visibility === "PUBLIC" ? "PUBLIC" : "PRIVATE";

      const updated = await tx.wishRoomReview.update({
        where: { id: dbId },
        data: update,
        include: { user: { select: { nickname: true } }, room: { select: { text: true, wishColor: true } }, congrats: { select: { userId: true } } },
      });
      return toReviewDto(updated, auth.userId);
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomReviewId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "후기 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    await prisma.$transaction(async (tx) => {
      const review = await tx.wishRoomReview.findUnique({ where: { id: dbId } });
      if (!review || review.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "후기를 찾을 수 없어요");
      if (review.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "내 후기만 지울 수 있어요");

      await tx.wishRoomReview.update({ where: { id: dbId }, data: { deletedAt: new Date() } });
    });

    return NextResponse.json({ success: true, data: { ok: true } }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
