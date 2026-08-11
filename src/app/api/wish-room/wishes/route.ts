// 공개(비인증) 소원 생성 API — Flutter "✨ 소원 빌기" 의식 플로우의 서버 확정 지점.
//
// [규칙]
//   - 회원당 최대 보유 개수는 WishRoomConfig(wish_room_max_wish_count)로 관리자가 조정한다.
//   - 첫 소원은 자동으로 대표 소원(isRepresentative=true)이 된다.
//   - 대표 소원이 이미 있으면 신규 소원은 서브(대표 아님)로 등록된다(대표 변경은 별도 API 영역).
//   - 복주머니 적립(wish_room_wish 규칙, 3개)은 luck-pouch-engine의 공용 엔진으로 처리한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  getOrCreateWishRoomProfile,
  getWishRoomConfigNumber,
  getEarnRuleAmount,
  serializeWish,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface CreateBody {
  userId?: number;
  categoryCode?: string;
  content?: string;
  isPublic?: boolean;
}

export async function POST(request: NextRequest) {
  let body: CreateBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const categoryCode = (body.categoryCode ?? "").trim();
  const content = (body.content ?? "").trim();
  const isPublic = body.isPublic === true;

  if (!categoryCode || !content) {
    return NextResponse.json(
      { success: false, error: "categoryCode, content는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (content.length > 500) {
    return NextResponse.json(
      { success: false, error: "소원 내용은 500자 이내로 작성해주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const category = await prisma.wishRoomCategory.findFirst({
      where: { code: categoryCode, isActive: true, deletedAt: null },
    });
    if (!category) {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 카테고리입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const result = await prisma.$transaction(async (tx) => {
      const profile = await getOrCreateWishRoomProfile(tx, userId);

      const activeCount = await tx.wishRoomWish.count({ where: { userId, status: "active" } });
      const maxCount = await getWishRoomConfigNumber("wish_room_max_wish_count", 3, tx);
      if (activeCount >= maxCount) {
        throw new Error(`MAX_WISH_COUNT:${maxCount}`);
      }

      const hasRepresentative = await tx.wishRoomWish.findFirst({
        where: { userId, status: "active", isRepresentative: true },
      });
      const maxEnergy = await getWishRoomConfigNumber("wish_room_max_energy", 300, tx);

      const wish = await tx.wishRoomWish.create({
        data: {
          userId,
          categoryCode,
          content,
          isPublic,
          isRepresentative: !hasRepresentative,
          energy: 0,
          maxEnergy,
        },
      });

      if (!hasRepresentative) {
        await tx.wishRoomProfile.update({
          where: { userId },
          data: { representativeWishId: wish.id },
        });
      }

      // 소원 등록 적립(wish_room_wish, 기본 3개) — 관리자 설정값 우선.
      const amount = await getEarnRuleAmount(tx, "wish_room_wish", 3);

      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount,
        sourceType: "wish_room_wish",
        sourceId: wish.id,
        memo: "소원방 소원 등록 보상",
      });

      const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });

      return { wish, profile, rewardAmount: earnOutcome.grantedAmount, balance: wallet?.balance ?? null };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          wish: serializeWish(result.wish),
          rewardAmount: result.rewardAmount,
          balance: result.balance,
        },
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
    if (message.startsWith("MAX_WISH_COUNT:")) {
      const max = message.split(":")[1];
      return NextResponse.json(
        { success: false, error: `소원은 최대 ${max}개까지 만들 수 있어요.` },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/wish-room/wishes] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원 생성에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
