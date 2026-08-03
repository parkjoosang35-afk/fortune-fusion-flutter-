// 공개(비인증) 지갑 적립(earn) API — WalletRepository.earn() 대응.
// wallets.balance(캐시)와 point_histories(원장)를 하나의 트랜잭션으로 함께 갱신한다.
// [인증 임시 방편] wallet/route.ts와 동일하게 userId를 바디로 받는다(기본값 1).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; amount?: number; reason?: string; sourceType?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const amount = Number(body.amount);
  const reason = body.reason ?? "적립";
  const sourceType = body.sourceType ?? "admin_adjust";

  if (!Number.isInteger(amount) || amount <= 0) {
    return NextResponse.json(
      { success: false, error: "amount는 1 이상의 정수여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // [복주머니 적립 구간표] 일일 총 적립 상한(일반 80/이벤트 120, 운영자 지급 제외)을
      // 클리핑하고, 이어서 오늘 누적 활동 점수 구간(3/5/8/12) 보너스를 함께 판정한다.
      const earnOutcome = await earnLuckPouch(tx, { userId, amount, sourceType, memo: reason });
      const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
      return {
        balance: wallet?.balance ?? earnOutcome.balanceAfter ?? 0,
        grantedAmount: earnOutcome.grantedAmount,
        capped: earnOutcome.capped,
        newlyGrantedTiers: earnOutcome.newlyGrantedTiers,
        todayScore: earnOutcome.todayScore,
      };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          balance: result.balance,
          grantedAmount: result.grantedAmount,
          capped: result.capped,
          activityScore: result.todayScore,
          activityTierBonusGranted: result.newlyGrantedTiers,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/wallet/earn] 실패:", e);
    return NextResponse.json(
      { success: false, error: "적립 처리 중 오류가 발생했습니다." },
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
