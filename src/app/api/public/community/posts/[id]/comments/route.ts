// 공개(비인증) 커뮤니티 게시글 댓글 조회/작성 API
// — CommunityPostRepository.getComments()/addComment() 대응.
// comments(폴리모픽, targetType='post') + community_posts.comment_count 캐시 갱신.
//
// [3단계 - 복주머니 커뮤니티 적립 연동] 댓글 작성 시 point_policies.community
// 정책(게시글/소원 작성과 동일 sourceType 재사용, 03단계 마스터 지시의 "적립: 글쓰기/
// 댓글"을 하나의 "커뮤니티 활동" 한도로 묶어 관리)을 적용해 복주머니를 지급한다.
// wishes/route.ts, community/posts/route.ts와 동일한 트랜잭션 패턴을 그대로 재사용.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePostDbId(idParam: string): number | null {
  const match = /^cp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function GET(
  _request: NextRequest,
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

  try {
    const comments = await prisma.comment.findMany({
      where: { targetType: "post", targetId: postId, status: "active", deletedAt: null },
      include: { user: true },
      orderBy: { createdAt: "asc" },
    });

    const data = comments.map((c) => ({
      id: `cc_${c.id}`,
      postId: `cp_${postId}`,
      authorNickname: c.user.nickname,
      content: c.content,
      createdAt: c.createdAt.toISOString(),
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/community/posts/[id]/comments] 실패:", e);
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
  const { id } = await params;
  const postId = parsePostDbId(id);
  if (postId === null) {
    return NextResponse.json(
      { success: false, error: "게시글 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number; content?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const userId = Number(body.userId ?? 1);
  const content = (body.content ?? "").trim();
  if (!content) {
    return NextResponse.json(
      { success: false, error: "댓글 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const post = await tx.communityPost.findUnique({ where: { id: postId } });
      if (!post) throw new Error("POST_NOT_FOUND");
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new Error("USER_NOT_FOUND");

      const comment = await tx.comment.create({
        data: { targetType: "post", targetId: postId, userId, content },
      });
      await tx.communityPost.update({
        where: { id: postId },
        data: { commentCount: post.commentCount + 1 },
      });

      // [복주머니 적립 구간표] 댓글 작성 +3 (일 5회 제한) — point_policies.sourceType="community_comment".
      // (과거에는 게시글과 동일한 sourceType="community"를 공유했으나, 수치/한도가
      // 서로 다르므로(게시글 8/일2, 댓글 3/일5) 별도 sourceType으로 분리했다.)
      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "community_comment" } });
      const isActive = policy ? policy.isActive : true;
      const earnAmount = policy?.amount ?? 3;
      const dailyLimit = policy?.dailyLimit ?? 5;
      let rewardPoint = 0;
      if (isActive && earnAmount > 0) {
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayCount = await tx.pointHistory.count({
          where: { userId, sourceType: "community_comment", type: "earn", createdAt: { gte: todayStart } },
        });
        if (todayCount < dailyLimit) {
          const outcome = await earnLuckPouch(tx, {
            userId,
            amount: earnAmount,
            sourceType: "community_comment",
            sourceId: comment.id,
            memo: "댓글 작성 보상",
          });
          rewardPoint = outcome.grantedAmount;
        }
      }

      return { comment, user, rewardPoint };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `cc_${result.comment.id}`,
          postId: `cp_${postId}`,
          authorNickname: result.user.nickname,
          content: result.comment.content,
          createdAt: result.comment.createdAt.toISOString(),
          rewardPoint: result.rewardPoint,
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
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/community/posts/[id]/comments] 실패:", e);
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
