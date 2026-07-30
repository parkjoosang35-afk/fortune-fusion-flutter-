// 공개(비인증) 소원성 "성취 후기" 등록/조회 API — 신규 기능.
// wish_reviews 테이블(신설). 최종 레벨(4) 도달 소원에 대해 사용자가 후기를 남길 수
// 있으며, isFeatured는 관리자가 CMS(/community/wish-castle)에서 수동 선정한다.
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
    const reviews = await prisma.wishReview.findMany({
      where: { wishId, status: "visible" },
      include: { wish: { include: { user: true } } },
      orderBy: { createdAt: "desc" },
    });
    const data = reviews.map((r) => ({
      id: `wr_${r.id}`,
      wishId: `wp_${wishId}`,
      authorNickname: r.wish.isAnonymous ? "익명" : r.wish.user.nickname,
      content: r.content,
      isFeatured: r.isFeatured,
      createdAt: r.createdAt.toISOString(),
    }));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/[id]/reviews] 실패:", e);
    return NextResponse.json(
      { success: false, error: "후기를 불러오지 못했습니다." },
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
      { success: false, error: "후기 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const wish = await prisma.wish.findUnique({ where: { id: wishId } });
    if (!wish) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (wish.candleLevel < 4) {
      return NextResponse.json(
        { success: false, error: "최종 단계에 도달한 소원만 후기를 남길 수 있습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const review = await prisma.wishReview.create({
      data: { wishId, userId, content },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wr_${review.id}`,
          wishId: `wp_${wishId}`,
          content: review.content,
          isFeatured: review.isFeatured,
          createdAt: review.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/wishes/[id]/reviews] 실패:", e);
    return NextResponse.json(
      { success: false, error: "후기 등록에 실패했습니다." },
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
