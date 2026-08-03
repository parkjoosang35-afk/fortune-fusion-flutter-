// 공개(비인증) 소원 댓글 조회/작성 API — WishPostRepository.getComments()/addComment() 대응.
// comments(폴리모픽, targetType='wish'). wishes.comment_count 캐시 컬럼이 없으므로
// (04A L-3 wishes에는 comment_count 캐시가 없음, 04A상 community_posts에만 존재)
// 응답 시점에 comments 테이블을 직접 count해서 내려준다(GET /api/public/wishes와 동일 방식).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { computeCandleLevel, getCandleLevelThresholds, getWishConfigValue, WISH_MAX_LEVEL } from "@/lib/wish-castle";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseWishDbId(idParam: string): number | null {
  const match = /^wp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const wishId = parseWishDbId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "소원 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const comments = await prisma.comment.findMany({
      where: { targetType: "wish", targetId: wishId, status: "active", deletedAt: null },
      include: { user: true },
      orderBy: { createdAt: "asc" },
    });

    const data = comments.map((c) => ({
      id: `wc_${c.id}`,
      wishId: `wp_${wishId}`,
      authorNickname: c.user.nickname,
      content: c.content,
      createdAt: c.createdAt.toISOString(),
      // [재화 구조 정리 - 재연결] 댓글 응원(cheer)/공감(empathize) 누적치.
      cheerCount: c.cheerCount,
      empathizeCount: c.empathizeCount,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/[id]/comments] 실패:", e);
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
  const wishId = parseWishDbId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "소원 id가 올바르지 않습니다." },
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
    // [소원성(Wish Castle) 확장] 응원 댓글 작성 시 wish_config.comment_bokju_reward
    // 만큼 자동으로 복주머니를 지급한다(관리자가 0으로 설정하면 비활성화).
    // 트랜잭션 밖에서 설정값/임계값을 미리 읽어 트랜잭션 내부 로직을 단순화한다.
    const rewardStr = await getWishConfigValue("comment_bokju_reward", "1");
    const reward = Math.max(0, Math.floor(Number(rewardStr) || 0));
    const thresholds = reward > 0 ? await getCandleLevelThresholds() : null;

    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wish.findUnique({ where: { id: wishId } });
      if (!wish) throw new Error("WISH_NOT_FOUND");
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new Error("USER_NOT_FOUND");

      const comment = await tx.comment.create({
        data: { targetType: "wish", targetId: wishId, userId, content },
      });

      let bokjuAwarded = 0;
      let leveledUp = false;
      if (reward > 0 && thresholds) {
        await tx.wishBokju.create({
          data: { wishId, userId, amount: reward, source: "comment_reward" },
        });
        bokjuAwarded = reward;
        const newBokjuCount = wish.bokjuCount + reward;
        const newLevel = computeCandleLevel(newBokjuCount, thresholds);
        leveledUp = newLevel > wish.candleLevel;
        const reachedMax = newLevel >= WISH_MAX_LEVEL && wish.candleLevel < WISH_MAX_LEVEL;
        await tx.wish.update({
          where: { id: wishId },
          data: {
            bokjuCount: newBokjuCount,
            candleLevel: newLevel,
            achievedAt: reachedMax ? new Date() : wish.achievedAt,
          },
        });
      }

      return { comment, user, bokjuAwarded, leveledUp };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wc_${result.comment.id}`,
          wishId: `wp_${wishId}`,
          authorNickname: result.user.nickname,
          content: result.comment.content,
          createdAt: result.comment.createdAt.toISOString(),
          bokjuAwarded: result.bokjuAwarded,
          leveledUp: result.leveledUp,
          cheerCount: result.comment.cheerCount,
          empathizeCount: result.comment.empathizeCount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WISH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/[id]/comments] 실패:", e);
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
