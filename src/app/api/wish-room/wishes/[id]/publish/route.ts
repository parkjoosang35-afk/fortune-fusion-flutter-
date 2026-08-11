// 공개(비인증) 소원 게시판 공개 API — "💫 원할 때 소원게시판에 공개하세요".
//
// [소원게시판 vs 소원방 분리 규칙] 소원방(WishRoomWish)은 개인 공간의 데이터이고,
// 소원게시판(Wish, 기존 "소원성" 테이블)은 커뮤니티 공개 공간이다. 이 API는 사용자가
// "공개"를 선택했을 때만 게시판에 파생 게시물을 생성한다 — 자동 공개는 없다.
// 이미 공개된 소원(publicWishId 존재)을 다시 호출하면 중복 게시하지 않고 기존
// 게시물을 그대로 반환한다(publishToWishBoard의 idempotency).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  publishToWishBoard,
  serializeWish,
  parseWishRoomWishId,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface PublishBody {
  userId?: number;
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const wishId = parseWishRoomWishId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: PublishBody;
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 회원간 데이터 격리 — userId로 항상 필터링.
      const wish = await tx.wishRoomWish.findFirst({ where: { id: wishId, userId, status: "active" } });
      if (!wish) throw new Error("WISH_NOT_FOUND");

      const publicWish = await publishToWishBoard(tx, {
        id: wish.id,
        userId: wish.userId,
        categoryCode: wish.categoryCode,
        content: wish.content,
        publicWishId: wish.publicWishId,
      });

      // publishToWishBoard가 신규 생성 분기에서만 wishRoomWish를 갱신하므로,
      // 이미 공개된 경우(기존 반환 분기)까지 포함해 항상 최신 상태를 다시 읽는다.
      const refreshedWish = await tx.wishRoomWish.findUniqueOrThrow({ where: { id: wish.id } });

      return { wish: refreshedWish, publicWishId: publicWish.id };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          wish: serializeWish(result.wish),
          publicWishId: result.publicWishId,
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
    console.error("[POST /api/wish-room/wishes/[id]/publish] 실패:", e);
    return NextResponse.json(
      { success: false, error: "게시판 공개 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
