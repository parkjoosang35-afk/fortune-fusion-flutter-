// 공개(비인증) 지갑 적립(earn) API — WalletRepository.earn() 대응.
// wallets.balance(캐시)와 point_histories(원장)를 하나의 트랜잭션으로 함께 갱신한다.
// [인증 임시 방편] wallet/route.ts와 동일하게 userId를 바디로 받는다(기본값 1).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch, checkPolicyEligibility } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// [복주머니 정책표 재정리 - 2026] sourceType별 기본 판정 범위(scope).
// "1일 N회" 정책(출석/소원벽 등)은 daily, "평생 N회" 정책(가입/첫로그인 등)은 lifetime으로
// 판정한다. 목록에 없는 sourceType은 body.scope(기본 daily)를 그대로 사용한다.
const LIFETIME_SCOPE_SOURCE_TYPES = new Set(["signup_reward", "first_login_reward"]);

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    amount?: number;
    reason?: string;
    sourceType?: string;
    sourceId?: number;
    scope?: "daily" | "weekly" | "lifetime";
  };
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
  const sourceId = Number.isInteger(body.sourceId) ? Number(body.sourceId) : undefined;
  const scope = body.scope ?? (LIFETIME_SCOPE_SOURCE_TYPES.has(sourceType) ? "lifetime" : "daily");

  if (!Number.isInteger(amount) || amount <= 0) {
    return NextResponse.json(
      { success: false, error: "amount는 1 이상의 정수여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // [복주머니 정책표 §3/§5] sourceType별 "1일 N회 / 평생 N회" 제한(PointPolicy.dailyLimit)을
      // 먼저 판정한다. 관리자/시스템 수동 지급(admin_adjust)은 정책 테이블에 항목이 없으므로
      // dailyLimit=null → 항상 통과한다.
      const eligibility = await checkPolicyEligibility(tx, userId, sourceType, { scope, sourceId });
      if (!eligibility.eligible) {
        const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
        return {
          blocked: eligibility.reason,
          balance: wallet?.balance ?? 0,
          grantedAmount: 0,
          capped: false,
          newlyGrantedTiers: [] as number[],
          todayScore: 0,
          comboGranted: false,
          comboAmount: 0,
        };
      }

      // [복주머니 적립 구간표] 일일 총 적립 상한(일반 80/이벤트 120, 운영자 지급 제외)을
      // 클리핑하고, 이어서 오늘 누적 활동 점수 구간(3/5/8/12) 보너스를 함께 판정한다.
      const earnOutcome = await earnLuckPouch(tx, { userId, amount, sourceType, sourceId, memo: reason });
      const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
      return {
        blocked: null as string | null,
        balance: wallet?.balance ?? earnOutcome.balanceAfter ?? 0,
        grantedAmount: earnOutcome.grantedAmount,
        capped: earnOutcome.capped,
        newlyGrantedTiers: earnOutcome.newlyGrantedTiers,
        todayScore: earnOutcome.todayScore,
        comboGranted: earnOutcome.comboGranted,
        comboAmount: earnOutcome.comboAmount,
      };
    });

    if (result.blocked) {
      // [복주머니 정책표 §5 예외처리] 이미 오늘/평생 지급된 정책 — 실패가 아니라 "지급 없음"으로
      // 안내한다(success:true, grantedAmount:0). 클라이언트는 이를 "이미 받음"으로 표시할 수 있다.
      return NextResponse.json(
        {
          success: true,
          data: {
            balance: result.balance,
            grantedAmount: 0,
            capped: false,
            activityScore: 0,
            activityTierBonusGranted: [],
            blockedReason: result.blocked,
            comboGranted: false,
            comboAmount: 0,
          },
        },
        { headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          balance: result.balance,
          grantedAmount: result.grantedAmount,
          capped: result.capped,
          activityScore: result.todayScore,
          activityTierBonusGranted: result.newlyGrantedTiers,
          comboGranted: result.comboGranted,
          comboAmount: result.comboAmount,
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
