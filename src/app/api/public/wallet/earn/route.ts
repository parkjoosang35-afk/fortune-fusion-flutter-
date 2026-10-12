// 공개(비인증) 지갑 적립(earn) API — WalletRepository.earn() 대응.
// wallets.balance(캐시)와 point_histories(원장)를 하나의 트랜잭션으로 함께 갱신한다.
// [인증 임시 방편] wallet/route.ts와 동일하게 userId를 바디로 받는다(기본값 1).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch, checkPolicyEligibility } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

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

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  const amount = Number(body.amount);
  const reason = body.reason ?? "적립";
  const sourceType = body.sourceType;
  const sourceId = Number.isInteger(body.sourceId) ? Number(body.sourceId) : undefined;
  // [경제 감사 2026-10-12 C-1] scope를 클라이언트가 지정하지 못하게 한다 —
  // 기존에는 body.scope로 signup_reward(평생 1회)의 판정 범위를 매일 1회로
  // 우회할 수 있었다. 판정 범위는 서버가 sourceType으로부터만 결정한다.
  const scope = LIFETIME_SCOPE_SOURCE_TYPES.has(sourceType ?? "") ? "lifetime" : "daily";

  // [경제 감사 2026-10-12 C-1] 무제한 포인트 발행 차단 — 상한 면제 계열
  // sourceType(CAP_EXEMPT_SOURCE_TYPES: admin_adjust/admin_grant/manual/
  // signup_reward/first_login_reward)은 클라이언트 호출로 허용하면
  // `POST /wallet/earn {"sourceType":"admin_adjust","amount":999999}`로
  // 일일 상한(80/120)조차 우회된다. 이 계열은 서버 내부 경로(회원가입
  // 시딩, 관리자 지급)에서만 발행해야 하며, 이 라우트는 명시적 sourceType
  // 없이도 호출할 수 없다(기존 기본값 "admin_adjust" 위임 제거).
  const BLOCKED_CLIENT_SOURCE_TYPES = new Set([
    "admin_adjust",
    "admin_grant",
    "manual",
    "signup_reward",
    "first_login_reward",
  ]);
  if (!sourceType || BLOCKED_CLIENT_SOURCE_TYPES.has(sourceType)) {
    return NextResponse.json(
      { success: false, error: "호출할 수 없는 sourceType입니다." },
      { status: 403, headers: CORS_HEADERS }
    );
  }

  if (!Number.isInteger(amount) || amount <= 0 || amount > 1_000_000) {
    return NextResponse.json(
      { success: false, error: "amount는 1 이상 1,000,000 이하의 정수여야 합니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
