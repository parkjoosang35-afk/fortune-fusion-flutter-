// 공개(비인증) 행운상자 시청 완료 API — Flutter 화면의 "완료(서버검증)"
// 단계. [행운상자 - 복주머니 탭 신규 기능] 이 API가 유일한 지급 지점이다
// (서버 최종 지급 원칙, dev-spec.md §0-3 "보상은 서버가 결정").
// fortune-ad complete/route.ts와 동일한 패턴:
//   1) sessionId로 해당 시청 세션(PouchBoxOpenLog, PENDING)을 조회
//   2) 이미 COMPLETED면 중복 지급 없이 기존 결과를 그대로 반환(idempotency)
//   3) 자격을 다시 검증(그 사이 하루 5회 한도가 소진됐을 수 있음)
//   4) PENDING → COMPLETED 원자적 전환(updateMany where status=PENDING)으로
//      동시요청 중복지급을 차단
//   5) 서버에서만 rollPouchBoxReward()로 보상을 굴리고, earnLuckPouch()로
//      실제 지급 — sourceType: "POUCH_BOX_REWARD"는 전역 일일 적립 상한에서
//      면제되고(CAP_EXEMPT_SOURCE_TYPES), 활동점수 구간 보너스에는 반영되지
//      않는다(AD_WATCH_REWARD와 동일 설계).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  checkPouchBoxEligibility,
  POUCH_BOX_REASON_LABELS,
  rollPouchBoxReward,
} from "@/lib/pouch-box-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

interface CompleteBody {
  userId?: number;
  sessionId?: string;
  watchSeconds?: number;
}

export async function POST(request: NextRequest) {
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

  if (!sessionId) {
    return NextResponse.json(
      { success: false, error: "sessionId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const openLog = await prisma.pouchBoxOpenLog.findFirst({
      where: { sessionId, userId },
    });
    if (!openLog) {
      return NextResponse.json(
        { success: false, error: "시청 세션을 찾을 수 없습니다. 처음부터 다시 시도해주세요." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // 1) idempotency — 이미 지급 완료된 세션이면 재지급 없이 기존 결과 그대로 반환.
    if (openLog.rewardStatus === "COMPLETED") {
      const wallet = await prisma.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      return NextResponse.json(
        {
          success: true,
          idempotent: true,
          data: {
            rewardAmount: openLog.rewardAmount,
            rewardTier: openLog.rewardTier,
            balance: wallet?.balance ?? null,
          },
        },
        { headers: CORS_HEADERS }
      );
    }
    if (openLog.rewardStatus === "FAILED") {
      return NextResponse.json(
        { success: false, error: "이미 실패 처리된 시청 세션입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // 2) 자격 재검증 — 시청 시작 이후 하루 5회 한도가 그 사이 소진됐을 수 있다
    //    (여러 기기/탭에서 동시에 열었을 가능성 방어).
    const eligibility = await checkPouchBoxEligibility(userId);
    if (!eligibility.eligible) {
      await prisma.pouchBoxOpenLog.updateMany({
        where: { id: openLog.id, rewardStatus: "PENDING" },
        data: { rewardStatus: "FAILED", completedAt: new Date(), watchSeconds },
      });
      return NextResponse.json(
        {
          success: false,
          error: eligibility.reason ? POUCH_BOX_REASON_LABELS[eligibility.reason] : "지금은 보상을 받을 수 없습니다.",
          reason: eligibility.reason,
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // 3) 보상은 오직 서버에서만 결정한다(클라이언트 랜덤 절대 금지 — 어뷰징 방지).
    const { amount: rewardAmount, tier: rewardTier } = rollPouchBoxReward();

    const result = await prisma.$transaction(async (tx) => {
      // PENDING → COMPLETED 원자적 전환. 동시에 두 개의 complete 요청이 들어와도
      // 이 updateMany는 하나만 count:1로 성공하고 나머지는 count:0으로 걸러진다.
      const claim = await tx.pouchBoxOpenLog.updateMany({
        where: { id: openLog.id, rewardStatus: "PENDING" },
        data: {
          rewardStatus: "COMPLETED",
          completedAt: new Date(),
          watchSeconds,
          rewardAmount,
          rewardTier,
          idempotencyKey: openLog.sessionId,
        },
      });

      if (claim.count === 0) {
        // 다른 동시 요청이 먼저 선점 — 이미 지급된 것으로 간주하고 현재 잔액만 반환.
        const already = await tx.pouchBoxOpenLog.findUnique({ where: { id: openLog.id } });
        const wallet = await tx.wallet.findFirst({
          where: { userId, currencyType: "POINT", deletedAt: null },
        });
        return {
          alreadyClaimed: true,
          rewardAmount: already?.rewardAmount ?? rewardAmount,
          rewardTier: already?.rewardTier ?? rewardTier,
          balance: wallet?.balance ?? null,
        };
      }

      // 실제 지급 — 공용 복주머니 적립 엔진 재사용.
      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount: rewardAmount,
        sourceType: "POUCH_BOX_REWARD",
        sourceId: openLog.id,
        memo: `행운상자 보상 +${rewardAmount} 복주머니 (${rewardTier})`,
      });
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });

      return {
        alreadyClaimed: false,
        rewardAmount,
        rewardTier,
        balance: wallet?.balance ?? earnOutcome.balanceAfter ?? null,
      };
    });

    // 완료 이후 남은 횟수(결과 화면 "다른 상자 확인하기 (N회)" 표시용).
    const afterEligibility = await checkPouchBoxEligibility(userId);

    return NextResponse.json(
      {
        success: true,
        idempotent: result.alreadyClaimed,
        data: {
          rewardAmount: result.rewardAmount,
          rewardTier: result.rewardTier,
          balance: result.balance,
          dailyLeft: afterEligibility.dailyLeft,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/pouch-box/complete] 실패:", e);
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
