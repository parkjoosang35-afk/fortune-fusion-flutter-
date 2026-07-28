// 공개(비인증) 커뮤니티 게시글 좋아요 토글 API — CommunityPostRepository.toggleLike() 대응.
// likes(폴리모픽, targetType='post') UQ(targetType,targetId,userId) 제약을 이용해
// 이미 좋아요한 경우는 delete, 아니면 create + community_posts.like_count 캐시 갱신.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePostDbId(idParam: string): number | null {
  const match = /^cp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const postId = parsePostDbId(id);
  if (postId === null) {
    return NextResponse.json(
      { success: false, error: "게시글 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const post = await tx.communityPost.findUnique({
        where: { id: postId },
        include: { board: true, user: true },
      });
      if (!post) throw new Error("POST_NOT_FOUND");

      const existing = await tx.like.findUnique({
        where: { targetType_targetId_userId: { targetType: "post", targetId: postId, userId } },
      });

      let isLikedByMe: boolean;
      let likeCount: number;
      if (existing) {
        await tx.like.delete({ where: { id: existing.id } });
        likeCount = Math.max(0, post.likeCount - 1);
        isLikedByMe = false;
      } else {
        await tx.like.create({ data: { targetType: "post", targetId: postId, userId } });
        likeCount = post.likeCount + 1;
        isLikedByMe = true;
      }

      const updated = await tx.communityPost.update({
        where: { id: postId },
        data: { likeCount },
      });

      return { updated, board: post.board, user: post.user, isLikedByMe };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `cp_${result.updated.id}`,
          boardId: `board_${result.updated.boardId}`,
          boardName: result.board.name,
          authorNickname: result.user.nickname,
          title: result.updated.title,
          content: result.updated.content,
          likeCount: result.updated.likeCount,
          commentCount: result.updated.commentCount,
          isPinned: result.updated.isPinned,
          isLikedByMe: result.isLikedByMe,
          isMine: result.updated.userId === userId,
          createdAt: result.updated.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "POST_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "게시글을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/community/posts/[id]/like] 실패:", e);
    return NextResponse.json(
      { success: false, error: "좋아요 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
