// [소원방 개편 · 3] 소원을 응원한 사람 목록 조회 API.
//
// 기존 Like 폴리모픽 모델(targetType='wish')에는 이미 각 응원의 userId가
// 저장되어 있지만(중복 방지용 @@unique 제약), 지금까지 어떤 엔드포인트도
// 이 목록을 노출하지 않아 Wish.supportCount 합계 숫자만 볼 수 있었다.
// 새 테이블/필드 없이 기존 Like 레코드를 User.nickname과 조인해 반환한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, parseWishDbId } from "../../_shared";

export const dynamic = "force-dynamic";

const SUPPORT_TARGET_TYPE = "wish";

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

  try {
    const likes = await prisma.like.findMany({
      where: { targetType: SUPPORT_TARGET_TYPE, targetId: dbId },
      orderBy: { createdAt: "desc" },
      take: 100,
      include: { user: { select: { nickname: true } } },
    });

    const supporters = likes.map((l) => ({
      userId: l.userId,
      nickname: l.user?.nickname ?? "익명",
      createdAt: l.createdAt.toISOString(),
    }));

    return NextResponse.json(
      { success: true, data: supporters },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/wishes/:id/supporters] 실패:", e);
    return NextResponse.json(
      { success: false, error: "응원자 목록 조회에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
