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

    // [STEP04] 현재 사용자가 이미 이 소원을 응원했는지 Like 테이블로 확인한다
    // (서버가 최종 판단 — 클라이언트 로컬 플래그를 신뢰하지 않는다).
    let isSupportedByMe = false;
    if (auth) {
      const like = await prisma.like.findUnique({
        where: {
          targetType_targetId_userId: {
            targetType: "wish",
            targetId: dbId,
            userId: auth.userId,
          },
        },
      });
      isSupportedByMe = like != null;
    }

    const dto = toWishDto(wish as unknown as WishRow, auth?.userId ?? null, isSupportedByMe);
    return NextResponse.json({ success: true, data: dto }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/:id] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 조회에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

// [소원방 개편 · 5] 내 소원 삭제 — 새 필드/스키마 없이 기존 `deletedAt`
// soft-delete 컬럼만 사용한다. 본인 소유 소원만 삭제 가능하며, 삭제 후에는
// GET/공개 피드 등 모든 조회 경로에서 이미 `deletedAt != null` 또는
// `WISH_VISIBLE_WHERE` 필터로 제외된다(기존 조회 로직 변경 불필요).
export async function DELETE(
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
  if (!auth) {
    return NextResponse.json(
      { success: false, error: "로그인이 필요합니다." },
      { status: 401, headers: CORS_HEADERS }
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
    if (wish.userId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인 소원만 삭제할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    await prisma.wish.update({
      where: { id: dbId },
      data: { deletedAt: new Date() },
    });

    return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[DELETE /api/public/wishes/:id] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 삭제에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
