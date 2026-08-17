// 소원 상세 조회 API — WishWallRepository.fetchDetail() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  toWishDto,
  type WishRow,
} from "../_shared";

export const dynamic = "force-dynamic";

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

  const auth = await requireUser(request);

  try {
    const wish = await prisma.wish.findUnique({
      where: { id: dbId },
      include: { user: { select: { nickname: true } } },
    });

    if (!wish || wish.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // private_only 소원은 작성자 본인만 조회 가능.
    if (wish.status === "private_only" && wish.userId !== auth?.userId) {
      return NextResponse.json(
        { success: false, error: "비공개 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    if (wish.status !== "visible" && wish.status !== "gratitude" && wish.status !== "private_only") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const dto = toWishDto(wish as unknown as WishRow, auth?.userId ?? null);
    return NextResponse.json({ success: true, data: dto }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/:id] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 조회에 실패했습니다." },
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
