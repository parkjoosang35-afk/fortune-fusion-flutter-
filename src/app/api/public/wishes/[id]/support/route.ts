// 공개(비인증) 소원 "행운 보내기(응원)" 토글 API — WishPostRepository.toggleSupport() 대응.
// likes(폴리모픽, targetType='wish')를 재사용해 응원 토글 + wishes.support_count 캐시 갱신.
// [정책] Mock 단계 그대로 포인트 이동 없는 단순 응원 카운트로 유지한다
// (03§10.3/§18/§570 정책 미확정 - repository 주석과 동일한 결정 유지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseWishDbId(idParam: string): number | null {
  const match = /^wp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
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

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wish.findUnique({ where: { id: wishId }, include: { user: true } });
      if (!wish) throw new Error("WISH_NOT_FOUND");

      const existing = await tx.like.findUnique({
        where: { targetType_targetId_userId: { targetType: "wish", targetId: wishId, userId } },
      });

      let isSupportedByMe: boolean;
      let supportCount: number;
      if (existing) {
        await tx.like.delete({ where: { id: existing.id } });
        supportCount = Math.max(0, wish.supportCount - 1);
        isSupportedByMe = false;
      } else {
        await tx.like.create({ data: { targetType: "wish", targetId: wishId, userId } });
        supportCount = wish.supportCount + 1;
        isSupportedByMe = true;
      }

      const updated = await tx.wish.update({ where: { id: wishId }, data: { supportCount } });
      const commentCount = await tx.comment.count({
        where: { targetType: "wish", targetId: wishId, status: "active" },
      });

      return { updated, user: wish.user, isSupportedByMe, commentCount };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wp_${result.updated.id}`,
          authorNickname: result.updated.isAnonymous ? "익명" : result.user.nickname,
          content: result.updated.content,
          category: result.updated.category,
          isAnonymous: result.updated.isAnonymous,
          supportCount: result.updated.supportCount,
          commentCount: result.commentCount,
          isSupportedByMe: result.isSupportedByMe,
          isMine: result.updated.userId === userId,
          createdAt: result.updated.createdAt.toISOString(),
          goalTag: result.updated.goalTag,
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
    console.error("[POST /api/public/wishes/[id]/support] 실패:", e);
    return NextResponse.json(
      { success: false, error: "응원 처리에 실패했습니다." },
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
