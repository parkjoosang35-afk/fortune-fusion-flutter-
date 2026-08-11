// 공개(비인증) 소원 깨우기 API — "🥀 소원의 빛이 조금 약해졌어요" 복귀 시 CTA.
//
// [설계] care API와 별개로, 오래 미접속해 에너지가 감쇠된 소원을 회복시키는
// 전용 액션이다. care와 달리 하루 무료 횟수 제한이 없는 대신, 감쇠가 실제로
// 발생한 상태(에너지가 낮아진 상태)에서만 유효하다 — 감쇠가 없는 소원에는
// "깨울 필요"가 없으므로 400을 반환한다. 소량의 복주머니(wish_room_wake 규칙,
// 기본 2개)를 지급해 복귀를 긍정적으로 강화한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  applyDecayIfNeeded,
  getWishRoomConfigNumber,
  getEarnRuleAmount,
  serializeWish,
  parseWishRoomWishId,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface WakeBody {
  userId?: number;
  wishId?: string;
  requestId?: string;
}

export async function POST(request: NextRequest) {
  let body: WakeBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const wishId = body.wishId ? parseWishRoomWishId(body.wishId) : null;
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "wishId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const requestId = body.requestId;

  try {
    if (requestId) {
      const existingLog = await prisma.wishRoomCareLog.findUnique({ where: { requestId } });
      if (existingLog) {
        const wish = await prisma.wishRoomWish.findUnique({ where: { id: existingLog.wishId } });
        const wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
        return NextResponse.json(
          {
            success: true,
            idempotent: true,
            data: { wish: wish ? serializeWish(wish) : null, rewardAmount: existingLog.rewardAmount, balance: wallet?.balance ?? null },
          },
          { headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wishRoomWish.findFirst({ where: { id: wishId, userId, status: "active" } });
      if (!wish) throw new Error("WISH_NOT_FOUND");

      const before = wish.energy;
      const { energyAfter, decayApplied } = await applyDecayIfNeeded(tx, wish);

      // 이번 요청에서 새로 감쇠가 발생하지 않았고, 과거에도 이미 최신 상태라면
      // "깨울 필요 없음"으로 판단한다(에너지가 이미 정상 범위).
      const wasWeak = decayApplied > 0 || before < wish.maxEnergy * 0.3;
      if (!wasWeak) {
        throw new Error("NOTHING_TO_WAKE");
      }

      const recoverAmount = await getWishRoomConfigNumber("wish_room_care_energy_gain", 20, tx);
      const recoveredEnergy = Math.min(wish.maxEnergy, energyAfter + recoverAmount);

      const updatedWish = await tx.wishRoomWish.update({
        where: { id: wish.id },
        data: { energy: recoveredEnergy, lastCaredAt: new Date() },
      });

      const rewardAmount = await getEarnRuleAmount(tx, "wish_room_wake", 2);
      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount: rewardAmount,
        sourceType: "wish_room_wake",
        sourceId: wish.id,
        memo: "소원 깨우기 보상",
      });

      await tx.wishRoomCareLog.create({
        data: {
          userId,
          wishId: wish.id,
          energyBefore: before,
          energyAfter: recoveredEnergy,
          rewardAmount: earnOutcome.grantedAmount,
          requestId: requestId ?? null,
        },
      });

      const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });

      return { wish: updatedWish, rewardAmount: earnOutcome.grantedAmount, balance: wallet?.balance ?? null };
    });

    return NextResponse.json(
      { success: true, data: { wish: serializeWish(result.wish), rewardAmount: result.rewardAmount, balance: result.balance } },
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
    if (message === "NOTHING_TO_WAKE") {
      return NextResponse.json(
        { success: false, error: "이 소원은 아직 힘이 약해지지 않았어요." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/wish-room/wake] 실패:", e);
    return NextResponse.json(
      { success: false, error: "깨우기 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
