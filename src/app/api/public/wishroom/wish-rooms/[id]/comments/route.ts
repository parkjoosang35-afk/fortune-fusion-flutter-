// 댓글(응원 메시지) — Flutter WrRepository.comments()/postComment() 대응.
// [원본] app/api.js 라우트 6(GET)/6'(POST) · GET|POST /wish-rooms/{id}/comments.
// 60자 제한, 분당 10회 레이트리밋, 금칙어/개인정보 필터(force=true로 PII 경고도 우회 —
// 원본과 동일하게 항상 force로 필터링해 PII_WARNING이 아닌 FILTERED만 차단).
// 차단한 사용자의 댓글은 목록에서 숨긴다(기존 Like 재사용이 아닌 신규 WishRoomBlock 사용).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { filterText, WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, enforceRateLimitAndLog, getBlockedUserIds } from "../../../_shared";

export const dynamic = "force-dynamic";

function toCommentDto(c: { id: number; userId: number; text: string; createdAt: Date; user?: { nickname: string } | null }, nicknameFallback = "") {
  return {
    id: `wrc_${c.id}`,
    author: c.user?.nickname ?? nicknameFallback,
    text: c.text,
    at: c.createdAt.getTime(),
  };
}

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");

      const blocked = auth ? await getBlockedUserIds(tx, auth.userId) : new Set<number>();
      const comments = await tx.wishRoomComment.findMany({
        where: { roomId: dbId, status: "active", deletedAt: null },
        include: { user: { select: { nickname: true } } },
        orderBy: { createdAt: "desc" },
      });
      return comments.filter((c) => !blocked.has(c.userId)).map((c) => toCommentDto(c));
    });
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { text?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const dto = await prisma.$transaction(async (tx) => {
      await enforceRateLimitAndLog(tx, auth.userId, "comment");

      const room = await tx.wishRoom.findUnique({ where: { id: dbId } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");

      const text = (body.text ?? "").trim();
      if (text.length > 60) throw new WishRoomError(400, "TOO_LONG", "60자 이내로 적어주세요");
      filterText(text, true);

      const comment = await tx.wishRoomComment.create({
        data: { roomId: dbId, userId: auth.userId, text },
        include: { user: { select: { nickname: true } } },
      });
      await tx.wishRoom.update({ where: { id: dbId }, data: { commentCount: { increment: 1 } } });

      return toCommentDto(comment);
    });
    return NextResponse.json({ success: true, data: dto }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
