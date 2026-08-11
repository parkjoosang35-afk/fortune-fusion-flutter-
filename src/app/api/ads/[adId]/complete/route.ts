// 공개(비인증) 복주머니 광고 시청 완료 API — Flutter 광고 시청 팝업의 "완료(서버검증)" 단계.
// [신통방통 복주머니 광고 적립 시스템] 이 API가 유일한 지급 지점이다(서버 최종 지급 원칙).
// 클라이언트가 "다 봤다"고 알려와도 그대로 믿지 않고:
//   1) sessionId로 해당 시청 세션(FortuneAdWatchLog, PENDING)을 조회
//   2) 이미 COMPLETED면 중복 지급 없이 기존 결과를 그대로 반환(idempotency, §13 QA "중복요청 1회만 지급")
//   3) 자격을 다시 검증(관리자가 그 사이 OFF로 바꿨거나 일일 한도가 소진됐을 수 있음)
//   4) PENDING → COMPLETED 원자적 전환(updateMany where status=PENDING)으로 동시요청 중복지급을 차단
//   5) earnLuckPouch()로 실제 지급 — sourceType: "AD_WATCH_REWARD"는 전역 일일 적립 상한에서
//      면제되고(CAP_EXEMPT_SOURCE_TYPES), 활동점수 구간 보너스에는 반영되지 않는다(설계 확정 B안).
//      광고 자체의 일일 한도(perUserDailyLimit/dailyLimitReward)는 FortuneAdWatchLog로 별도 통제.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { checkFortuneAdEligibility, FORTUNE_AD_REASON_LABELS } from "@/lib/fortune-ad-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

interface CompleteBody {
  userId?: number;
  sessionId?: string;
  watchSeconds?: number;
}

export async function POST(request: NextRequest, context: { params: Promise<{ adId: string }> }) {
  const { adId: adIdParam } = await context.params;
  const adId = Number(adIdParam);

  let body: CompleteBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const sessionId = body.sessionId;
  const watchSeconds = Number.isInteger(body.watchSeconds) ? Number(body.watchSeconds) : null;

  if (!Number.isInteger(adId) || adId <= 0 || !sessionId) {
    return NextResponse.json(
      { success: false, error: "adId, sessionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const watchLog = await prisma.fortuneAdWatchLog.findFirst({
      where: { sessionId, adId, userId },
    });
    if (!watchLog) {
      return NextResponse.json(
        { success: false, error: "시청 세션을 찾을 수 없습니다. 처음부터 다시 시도해주세요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // 1) idempotency — 이미 지급 완료된 세션이면 재지급 없이 기존 결과 그대로 반환.
    if (watchLog.rewardStatus === "COMPLETED") {
      const wallet = await prisma.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      return NextResponse.json(
        {
          success: true,
          idempotent: true,
          data: {
            rewardAmount: watchLog.rewardAmount,
            balance: wallet?.balance ?? null,
          },
        },
        { headers: CORS_HEADERS }
      );
    }
    if (watchLog.rewardStatus === "FAILED") {
      return NextResponse.json(
        { success: false, error: "이미 실패 처리된 시청 세션입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // 2) 자격 재검증 — 시청 시작 이후 관리자가 광고를 껐거나(OFF), 일일 한도가 그 사이 소진됐을 수 있다.
    const eligibility = await checkFortuneAdEligibility(adId, userId);
    if (!eligibility.eligible) {
      await prisma.fortuneAdWatchLog.updateMany({
        where: { id: watchLog.id, rewardStatus: "PENDING" },
        data: { rewardStatus: "FAILED", completedAt: new Date(), watchSeconds },
      });
      return NextResponse.json(
        {
          success: false,
          error: eligibility.reason ? FORTUNE_AD_REASON_LABELS[eligibility.reason] : "지금은 보상을 받을 수 없습니다.",
          reason: eligibility.reason,
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    const ad = await prisma.fortuneAd.findUnique({ where: { id: adId } });
    if (!ad) {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 광고입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const result = await prisma.$transaction(async (tx) => {
      // 3) PENDING → COMPLETED 원자적 전환. 동시에 두 개의 complete 요청이 들어와도
      //    이 updateMany는 하나만 count:1로 성공하고 나머지는 count:0으로 걸러진다(중복지급차단).
      const claim = await tx.fortuneAdWatchLog.updateMany({
        where: { id: watchLog.id, rewardStatus: "PENDING" },
        data: {
          rewardStatus: "COMPLETED",
          completedAt: new Date(),
          watchSeconds,
          rewardAmount: ad.rewardAmount,
          idempotencyKey: watchLog.sessionId,
        },
      });

      if (claim.count === 0) {
        // 다른 동시 요청이 먼저 선점 — 이미 지급된 것으로 간주하고 현재 잔액만 반환.
        const wallet = await tx.wallet.findFirst({
          where: { userId, currencyType: "POINT", deletedAt: null },
        });
        return { alreadyClaimed: true, rewardAmount: ad.rewardAmount, balance: wallet?.balance ?? null };
      }

      // 4) 실제 지급 — 공용 복주머니 적립 엔진 재사용(§2 "기존 복주머니 시스템 재사용 필수").
      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount: ad.rewardAmount,
        sourceType: "AD_WATCH_REWARD",
        sourceId: ad.id,
        memo: `광고 시청 보상 +${ad.rewardAmount} 복주머니 (${ad.title})`,
      });
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });

      return {
        alreadyClaimed: false,
        rewardAmount: ad.rewardAmount,
        balance: wallet?.balance ?? earnOutcome.balanceAfter ?? null,
      };
    });

    return NextResponse.json(
      {
        success: true,
        idempotent: result.alreadyClaimed,
        data: {
          rewardAmount: result.rewardAmount,
          balance: result.balance,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/ads/[adId]/complete] 실패:", e);
    return NextResponse.json(
      { success: false, error: "보상 지급 처리 중 오류가 발생했습니다." },
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
