// 공개(비인증) 커뮤니티 게시글 목록/작성 API — CommunityPostRepository.getPosts()/createPost() 대응.
//
// [Phase6-2 - 커뮤니티 실API 연동] admin_web에 이미 존재하는 community_posts 테이블을
// 실제로 조회/작성하도록 연동한다. 게시글 작성 시 point_policies.community(기본 5P,
// 일일한도 10회) 정책에 따라 소량의 포인트를 지급하고(daily/fortune 계열과 달리
// "적립"형이므로 wallet/earn과 동일 패턴), missions.community_post 액션에도 반영한다.
//
// [id 포맷] Flutter 모델은 boardId를 문자열로 다루므로 `board_${id}` / `cp_${id}` 형태로
// 매핑한다(기존 admin_web CommunityBoard/CommunityPost의 정수 PK를 그대로 감싼 것).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { incrementMissionProgress } from "@/lib/mission-progress";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseBoardDbId(boardId: string): number | null {
  const match = /^board_(\d+)$/.exec(boardId);
  if (!match) return null;
  return Number(match[1]);
}

function toPostDto(
  p: {
    id: number;
    boardId: number;
    userId: number;
    title: string;
    content: string;
    likeCount: number;
    commentCount: number;
    isPinned: boolean;
    createdAt: Date;
  },
  boardName: string,
  authorNickname: string,
  currentUserId: number,
  isLikedByMe: boolean
) {
  return {
    id: `cp_${p.id}`,
    boardId: `board_${p.boardId}`,
    boardName,
    authorNickname,
    title: p.title,
    content: p.content,
    likeCount: p.likeCount,
    commentCount: p.commentCount,
    isPinned: p.isPinned,
    isLikedByMe,
    isMine: p.userId === currentUserId,
    createdAt: p.createdAt.toISOString(),
  };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const boardIdParam = searchParams.get("boardId");
  const sortByPopular = searchParams.get("sortByPopular") === "true";
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const where: { boardId?: number; status: string; deletedAt: null } = {
      status: "visible",
      deletedAt: null,
    };
    if (boardIdParam) {
      const dbId = parseBoardDbId(boardIdParam);
      if (dbId === null) {
        return NextResponse.json(
          { success: false, error: "boardId가 올바르지 않습니다." },
          { status: 400, headers: CORS_HEADERS }
        );
      }
      where.boardId = dbId;
    }

    const posts = await prisma.communityPost.findMany({
      where,
      include: { board: true, user: true },
      orderBy: sortByPopular
        ? [{ likeCount: "desc" }]
        : [{ isPinned: "desc" }, { createdAt: "desc" }],
    });

    const myLikes = await prisma.like.findMany({
      where: {
        targetType: "post",
        targetId: { in: posts.map((p) => p.id) },
        userId,
        status: "active",
      },
    });
    const likedSet = new Set(myLikes.map((l) => l.targetId));

    const data = posts.map((p) =>
      toPostDto(p, p.board.name, p.user.nickname, userId, likedSet.has(p.id))
    );

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/community/posts] 실패:", e);
    return NextResponse.json(
      { success: false, error: "게시글 목록을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; boardId?: string; title?: string; content?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const title = (body.title ?? "").trim();
  const content = (body.content ?? "").trim();

  if (!title || !content) {
    return NextResponse.json(
      { success: false, error: "제목과 내용을 모두 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const dbBoardId = body.boardId ? parseBoardDbId(body.boardId) : null;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const board = dbBoardId
        ? await tx.communityBoard.findUnique({ where: { id: dbBoardId } })
        : await tx.communityBoard.findFirst({ orderBy: { sortOrder: "asc" } });
      if (!board) {
        throw new Error("BOARD_NOT_FOUND");
      }

      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) {
        throw new Error("USER_NOT_FOUND");
      }

      const post = await tx.communityPost.create({
        data: { boardId: board.id, userId, title, content },
      });

      // 게시글 작성 리워드 (point_policies.community, 기본 5P/일일한도10) + 미션(community_post) 반영
      const policy = await tx.pointPolicy.findUnique({ where: { sourceType: "community" } });
      let rewardPoint = 0;
      if (policy?.isActive && policy.amount > 0) {
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayCount = await tx.pointHistory.count({
          where: { userId, sourceType: "community", type: "earn", createdAt: { gte: todayStart } },
        });
        const dailyLimit = policy.dailyLimit ?? Infinity;
        if (todayCount < dailyLimit) {
          rewardPoint = policy.amount;
          let wallet = await tx.wallet.findFirst({
            where: { userId, currencyType: "POINT", deletedAt: null },
          });
          if (!wallet) {
            wallet = await tx.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
          }
          const newBalance = wallet.balance + rewardPoint;
          await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance: newBalance, balanceSyncedAt: new Date() },
          });
          await tx.pointHistory.create({
            data: {
              walletId: wallet.id,
              userId,
              amount: rewardPoint,
              type: "earn",
              sourceType: "community",
              sourceId: post.id,
              balanceAfter: newBalance,
              memo: "커뮤니티 게시글 작성",
            },
          });
        }
      }

      const missionUpdates = await incrementMissionProgress(tx, userId, "community_post");

      return { post, board, user, rewardPoint, missionUpdates };
    });

    const dto = toPostDto(result.post, result.board.name, result.user.nickname, userId, false);
    return NextResponse.json(
      {
        success: true,
        data: { ...dto, rewardPoint: result.rewardPoint, missionUpdates: result.missionUpdates },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "BOARD_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "게시판을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/community/posts] 실패:", e);
    return NextResponse.json(
      { success: false, error: "게시글 작성에 실패했습니다." },
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
