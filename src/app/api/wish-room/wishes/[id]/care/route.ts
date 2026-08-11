// 공개(비인증) 소원 돌보기(힘주기) API — "✨ 오늘 소원에게 힘주기".
//
// [멱등성/중복방지] 클라이언트가 requestId(UUID)를 함께 보내면, WishRoomCareLog.
// requestId(unique)로 동일 요청의 중복 처리를 막는다(§ "동일 transaction 중복
// 처리 금지"). 이미 존재하는 requestId면 기존 로그 결과를 그대로 반환한다.
//
// [하루 제한] WishRoomConfig(wish_room_care_daily_free_count)로 관리자가 조정
// 가능한 하루 무료 횟수를 넘으면 409를 반환한다(§ "관리자 설정값 하드코딩 금지").
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  getOrCreateWishRoomProfile,
  getWishRoomConfigNumber,
  getEarnRuleAmount,
  applyDecayIfNeeded,
  todayRangeKst,
  serializeWish,
  parseWishRoomWishId,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface CareBody {
  userId?: number;
  requestId?: string;
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

  let body: CareBody;
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);
  const requestId = body.requestId;

  try {
    // 1) idempotency — 동일 requestId로 이미 처리된 요청이면 그대로 반환.
    if (requestId) {
      const existingLog = await prisma.wishRoomCareLog.findUnique({ where: { requestId } });
      if (existingLog) {
        const wish = await prisma.wishRoomWish.findUnique({ where: { id: existingLog.wishId } });
        const wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
        return NextResponse.json(
          {
            success: true,
            idempotent: true,
            data: {
              wish: wish ? serializeWish(wish) : null,
              rewardAmount: existingLog.rewardAmount,
              balance: wallet?.balance ?? null,
            },
          },
          { headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wishRoomWish.findFirst({ where: { id: wishId, userId, status: "active" } });
      if (!wish) throw new Error("WISH_NOT_FOUND");

      // 감쇠를 먼저 적용해 최신 에너지 기준으로 힘주기를 반영한다.
      const { energyAfter: energyBeforeCare } = await applyDecayIfNeeded(tx, wish);

      // 2) 하루 무료 제한 체크 — 해당 유저의 오늘 케어 로그 수(관리자 설정값 기준).
      const dailyFreeCount = await getWishRoomConfigNumber("wish_room_care_daily_free_count", 1, tx);
      const { start, end } = todayRangeKst();
      const todayCareCount = await tx.wishRoomCareLog.count({
        where: { userId, caredAt: { gte: start, lt: end } },
      });
      if (todayCareCount >= dailyFreeCount) {
        throw new Error(`DAILY_LIMIT_REACHED:${dailyFreeCount}`);
      }

      const energyGain = await getWishRoomConfigNumber("wish_room_care_energy_gain", 20, tx);
      const energyAfter = Math.min(wish.maxEnergy, energyBeforeCare + energyGain);

      const updatedWish = await tx.wishRoomWish.update({
        where: { id: wish.id },
        data: {
          energy: energyAfter,
          careCount: { increment: 1 },
          lastCaredAt: new Date(),
        },
      });

      // 3) 복주머니 적립(wish_room_care 규칙).
      const rewardAmount = await getEarnRuleAmount(tx, "wish_room_care", 3);
      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount: rewardAmount,
        sourceType: "wish_room_care",
        sourceId: wish.id,
        memo: "소원방 소원 돌보기 보상",
      });

      const careLog = await tx.wishRoomCareLog.create({
        data: {
          userId,
          wishId: wish.id,
          energyBefore: energyBeforeCare,
          energyAfter,
          rewardAmount: earnOutcome.grantedAmount,
          requestId: requestId ?? null,
        },
      });

      await tx.wishRoomProfile.update({
        where: { userId },
        data: { totalCareCount: { increment: 1 }, lastCaredAt: new Date() },
      });

      const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });

      return { wish: updatedWish, careLog, rewardAmount: earnOutcome.grantedAmount, balance: wallet?.balance ?? null };
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
    if (message === "WISH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message.startsWith("DAILY_LIMIT_REACHED:")) {
      return NextResponse.json(
        { success: false, error: "오늘은 이미 힘을 다 주었어요. 내일 다시 찾아주세요.", reason: "DAILY_LIMIT_REACHED" },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/wish-room/wishes/[id]/care] 실패:", e);
    return NextResponse.json(
      { success: false, error: "힘주기 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
