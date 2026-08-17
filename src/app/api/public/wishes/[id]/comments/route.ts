// 소원 댓글 목록/작성 API — WishWallRepository.fetchComments()/createComment() 대응.
//
// [작업6-1-F 최종 결정] 댓글은 이번 6-1 범위에 포함하되, 기존 Prisma `Comment`
// 모델(targetType='wish')을 그대로 재사용한다. 새로운 댓글 테이블은 만들지 않는다.
// community/posts/[id]/comments/route.ts와 동일한 폴리모픽 패턴을 따르되,
// 다음 두 가지를 이번 소원방 원칙에 맞게 다르게 처리한다:
//   1) 작성자(userId)는 body가 아니라 반드시 authenticateRequest()의 JWT로 결정한다
//      (community 댓글 API처럼 body.userId를 신뢰하지 않는다).
//   2) 복주머니 보상은 지급하지 않는다(사용자 최종 결정 10개 항목에 댓글 보상이
//      명시되지 않았으므로, 기존 community_comment 정책을 임의로 재사용/확장하지
//      않는다 — 새 정책 적용 필요 시 별도 승인 후 진행).
//
// [주의] Wish 모델에는 community_posts.comment_count 같은 캐시 필드가 없으므로
// (schema.prisma 확인 완료) 댓글 생성 시 Wish 레코드를 갱신하지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  unauthorizedResponse,
} from "../../_shared";

export const dynamic = "force-dynamic";

/** 댓글 열람/작성 가능 여부 — 상세 조회(route.ts)와 동일한 기준.
 * visible/gratitude는 누구나, private_only는 작성자 본인만 허용한다. */
function canAccessWish(
  wish: { status: string; userId: number },
  currentUserId: number | null
): boolean {
  if (wish.status === "visible" || wish.status === "gratitude") return true;
  if (wish.status === "private_only") return wish.userId === currentUserId;
  return false;
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // 댓글 목록 조회는 상세 조회처럼 비로그인 열람을 허용한다(단, private_only는 제외).
  const auth = await requireUser(request);

  try {
    const wish = await prisma.wish.findUnique({ where: { id: dbId } });
    if (!wish || wish.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (!canAccessWish(wish, auth?.userId ?? null)) {
      return NextResponse.json(
        { success: false, error: "비공개 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const comments = await prisma.comment.findMany({
      where: {
        targetType: "wish",
        targetId: dbId,
        status: "active",
        deletedAt: null,
      },
      include: { user: { select: { nickname: true } } },
      orderBy: { createdAt: "asc" },
    });

    const data = comments.map((c) => ({
      id: `wc_${c.id}`,
      wishId: id,
      authorName: c.user.nickname,
      text: c.content,
      createdAt: c.createdAt.toISOString(),
      isMine: auth != null && c.userId === auth.userId,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/:id/comments] 실패:", e);
    return NextResponse.json(
      { success: false, error: "댓글을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { text?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const content = (body.text ?? "").trim();
  if (!content) {
    return NextResponse.json(
      { success: false, error: "댓글 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (content.length > 500) {
    return NextResponse.json(
      { success: false, error: "댓글은 500자 이하여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const wish = await prisma.wish.findUnique({ where: { id: dbId } });
    if (!wish || wish.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (!canAccessWish(wish, auth.userId)) {
      return NextResponse.json(
        { success: false, error: "댓글을 남길 수 없는 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // userId는 오직 authenticateRequest()가 결정한 auth.userId만 사용한다.
    const comment = await prisma.comment.create({
      data: { targetType: "wish", targetId: dbId, userId: auth.userId, content },
      include: { user: { select: { nickname: true } } },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wc_${comment.id}`,
          wishId: id,
          authorName: comment.user.nickname,
          text: comment.content,
          createdAt: comment.createdAt.toISOString(),
          isMine: true,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/wishes/:id/comments] 실패:", e);
    return NextResponse.json(
      { success: false, error: "댓글 작성에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
