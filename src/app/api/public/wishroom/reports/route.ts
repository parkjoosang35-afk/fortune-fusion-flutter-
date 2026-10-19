// 신고 — Flutter WrRepository.report({roomId?, commentId?}) 대응. [SERVER] 신고 누적 즉시 반영.
// [원본] app/api.js §15 · POST /reports { roomId? | commentId? } → 즉시 숨김.
//
// 공용 `reports` 테이블(관리자 신고 큐)에도 함께 기록한다(targetType은 schema.prisma
// 주석에 이미 명시된 "wish_room"/"wish_room_comment" 화이트리스트 값 사용 —
// 기존 공용 /api/public/reports(소원성 도메인 wish/post/comment 전용)와는 별도 네임스페이스).
//
// [임계값] 기존 프로젝트 관례(schema.prisma WishRoomComment.status 주석의
// "신고 3회 자동 숨김", explore/route.ts의 reportCount<3 필터)를 그대로 따른다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, parseWishRoomCommentId } from "../_shared";

export const dynamic = "force-dynamic";

const HIDE_THRESHOLD = 3;

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { roomId?: string; commentId?: string; reason?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  if (!body.roomId && !body.commentId) {
    return NextResponse.json({ success: false, error: "신고할 대상을 정해주세요", code: "INVALID" }, { status: 400, headers: CORS_HEADERS });
  }

  const reason = (body.reason ?? "").trim() || "소원방 신고";

  try {
    await prisma.$transaction(async (tx) => {
      if (body.commentId) {
        const commentDbId = parseWishRoomCommentId(body.commentId);
        if (commentDbId === null) throw new WishRoomError(400, "INVALID_ID", "댓글 id가 올바르지 않습니다.");
        const comment = await tx.wishRoomComment.findUnique({ where: { id: commentDbId } });
        if (!comment || comment.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "댓글을 찾을 수 없어요");

        // [보안 수정 2026-10-19 — 전수검수 fix/wishroom-server-audit f655c6f 반영]
        // 동일 사용자가 같은 대상을 반복 신고해도 reportCount가 매번 +1 되므로,
        // 계정 1개만으로 "신고 3회 자동 숨김"(HIDE_THRESHOLD)을 조작할 수 있었다
        // (실제 코드 경로로 재현 가능). 1인 1회만 집계한다 — 이미 신고한 대상이면
        // 추가 집계/기록 없이 조용히 통과시킨다(사용자에게는 "신고 접수"로 응답).
        const priorCommentReport = await tx.report.findFirst({
          where: { targetType: "wish_room_comment", targetId: commentDbId, reporterId: auth.userId },
        });
        if (!priorCommentReport) {
          const newCount = comment.reportCount + 1;
          await tx.wishRoomComment.update({
            where: { id: commentDbId },
            data: { reportCount: newCount, status: newCount >= HIDE_THRESHOLD ? "hidden_by_report" : comment.status },
          });
          await tx.report.create({
            data: { targetType: "wish_room_comment", targetId: commentDbId, reporterId: auth.userId, reason },
          });
        }
      }

      if (body.roomId) {
        const roomDbId = parseWishRoomDbId(body.roomId);
        if (roomDbId === null) throw new WishRoomError(400, "INVALID_ID", "방 id가 올바르지 않습니다.");
        const room = await tx.wishRoom.findUnique({ where: { id: roomDbId } });
        if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");

        // [보안 수정 2026-10-19 — 전수검수 fix/wishroom-server-audit f655c6f 반영]
        // 동일 사용자 중복 신고 1인 1회 집계(댓글과 동일한 방어).
        const priorRoomReport = await tx.report.findFirst({
          where: { targetType: "wish_room", targetId: roomDbId, reporterId: auth.userId },
        });
        if (!priorRoomReport) {
          await tx.wishRoom.update({ where: { id: roomDbId }, data: { reportCount: { increment: 1 } } });
          await tx.report.create({
            data: { targetType: "wish_room", targetId: roomDbId, reporterId: auth.userId, reason },
          });
        }
      }
    });

    return NextResponse.json({ success: true, data: { hidden: true, reviewWithinHours: 24 } }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
