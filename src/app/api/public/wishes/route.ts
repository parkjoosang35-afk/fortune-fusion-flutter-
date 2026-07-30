// 공개(비인증) 소원게시판 피드/작성 API — WishPostRepository.getFeed()/createPost() 대응.
//
// [Phase6-2 - 커뮤니티 실API 연동] admin_web에 이미 존재하는 wishes 테이블을 실제로
// 조회/작성하도록 연동한다. 작성 시 point_policies.community 정책을 그대로 재사용해
// 소량의 포인트를 지급한다(커뮤니티 게시글 작성과 동일한 리워드 체계 - 04A상 wishes도
// community_posts와 함께 04A L-2/L-3로 나란히 설계된 콘텐츠 도메인이므로 자연스러움).
// missions.community_post 액션에도 함께 반영(별도 wish 전용 미션 action_type이
// 카탈로그에 없으므로, "커뮤니티 글 작성"으로 통합 - 소원도 게시글의 일종).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { incrementMissionProgress } from "@/lib/mission-progress";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function toWishDto(
  w: {
    id: number;
    userId: number;
    content: string;
    category: string;
    isAnonymous: boolean;
    supportCount: number;
    goalTag: string | null;
    createdAt: Date;
    candleLevel: number;
    bokjuCount: number;
    achievedAt: Date | null;
    isMilestoneShown: boolean;
  },
  commentCount: number,
  authorNickname: string,
  currentUserId: number,
  isSupportedByMe: boolean
) {
  return {
    id: `wp_${w.id}`,
    authorNickname: w.isAnonymous ? "익명" : authorNickname,
    content: w.content,
    category: w.category,
    isAnonymous: w.isAnonymous,
    supportCount: w.supportCount,
    commentCount,
    isSupportedByMe,
    isMine: w.userId === currentUserId,
    createdAt: w.createdAt.toISOString(),
    goalTag: w.goalTag,
    // [소원성(Wish Castle) 확장] 촛불 성장 시스템 필드 - 기존 필드는 그대로 유지
    candleLevel: w.candleLevel,
    bokjuCount: w.bokjuCount,
    achievedAt: w.achievedAt?.toISOString() ?? null,
    isMilestoneShown: w.isMilestoneShown,
  };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const tab = searchParams.get("tab") ?? "all"; // all/popular/mine
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const where: { userId?: number; status: string; deletedAt: null } = {
      status: "visible",
      deletedAt: null,
    };
    if (tab === "mine") where.userId = userId;

    const wishes = await prisma.wish.findMany({
      where,
      include: { user: true },
      orderBy: tab === "popular" ? [{ supportCount: "desc" }] : [{ createdAt: "desc" }],
    });

    const [commentCounts, mySupports] = await Promise.all([
      prisma.comment.groupBy({
        by: ["targetId"],
        where: { targetType: "wish", targetId: { in: wishes.map((w) => w.id) }, status: "active" },
        _count: { targetId: true },
      }),
      prisma.like.findMany({
        where: {
          targetType: "wish",
          targetId: { in: wishes.map((w) => w.id) },
          userId,
          status: "active",
        },
      }),
    ]);
    const commentCountMap = new Map(commentCounts.map((c) => [c.targetId, c._count.targetId]));
    const supportedSet = new Set(mySupports.map((l) => l.targetId));

    const data = wishes.map((w) =>
      toWishDto(
        w,
        commentCountMap.get(w.id) ?? 0,
        w.user.nickname,
        userId,
        supportedSet.has(w.id)
      )
    );

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 목록을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    content?: string;
    category?: string;
    isAnonymous?: boolean;
    goalTag?: string;
  };
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
  const category = body.category ?? "기타";
  const isAnonymous = Boolean(body.isAnonymous);
  const goalTag = body.goalTag ?? null;

  if (!content) {
    return NextResponse.json(
      { success: false, error: "내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new Error("USER_NOT_FOUND");

      const wish = await tx.wish.create({
        data: { userId, content, category, isAnonymous, goalTag },
      });

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
              sourceId: wish.id,
              balanceAfter: newBalance,
              memo: "소원 등록",
            },
          });
        }
      }

      const missionUpdates = await incrementMissionProgress(tx, userId, "community_post");

      return { wish, user, rewardPoint, missionUpdates };
    });

    const dto = toWishDto(result.wish, 0, result.user.nickname, userId, false);
    return NextResponse.json(
      {
        success: true,
        data: { ...dto, rewardPoint: result.rewardPoint, missionUpdates: result.missionUpdates },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 등록에 실패했습니다." },
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
