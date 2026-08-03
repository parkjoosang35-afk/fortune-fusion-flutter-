import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  resolveFallbackAttachment,
  recordAdRewardLog,
  serializeAttachment,
} from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

interface RewardFailedBody {
  userId?: number;
  policyId?: number;
  adSourceId?: number;
  reason?: "ad_fail" | "no_fill" | "cancel" | "timeout";
  idempotencyKey?: string;
}

export async function POST(request: NextRequest) {
  let body: RewardFailedBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 0);
  const policyId = Number(body.policyId ?? 0) || null;
  const adSourceId = Number(body.adSourceId ?? 0) || null;
  // [프리패스 테스트 인프라] §4 fail/no_fill/cancel/timeout을 각각 구별된 값으로 통과시키며,
  // 이전처럼 모두 "ad_fail"로 수렴하지 않는다(사유별 서로 다른 안내/로그가 필요).
  const VALID_REASONS = ["ad_fail", "no_fill", "cancel", "timeout"] as const;
  const reason = VALID_REASONS.includes(body.reason as (typeof VALID_REASONS)[number])
    ? (body.reason as (typeof VALID_REASONS)[number])
    : "ad_fail";
  const idempotencyKey = body.idempotencyKey || null;

  if (!userId || (!adSourceId && !policyId)) {
    return NextResponse.json(
      { success: false, error: "userId와 (adSourceId 또는 policyId) 중 하나는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 중복 로그 방지: 이미 동일 idempotencyKey로 기록된 실패 로그가 있으면 재기록하지 않고 동일 결과를 반환한다.
    let alreadyLogged = false;
    if (idempotencyKey) {
      const existing = await prisma.openPassAdRewardLog.findUnique({ where: { idempotencyKey } });
      if (existing) alreadyLogged = true;
    }

    if (!alreadyLogged && adSourceId) {
      // reason(cancel/timeout/no_fill)을 그대로 result에 반영해 관리자 로그 화면에서
      // "실패"와 "취소"와 "타임아웃"을 구분해 볼 수 있게 한다(§9 로그 result 필드).
      const result = reason === "ad_fail" ? "fail" : reason;
      await recordAdRewardLog({
        userId,
        adSourceId,
        passPolicyId: policyId,
        result,
        rewardGranted: false,
        idempotencyKey,
      });
    }

    const fallback = await resolveFallbackAttachment(adSourceId, policyId);

    let happyMoneyPrice: number | null = null;
    let alternateCtaHappyMoneyPurchase = false;
    if (policyId) {
      const policy = await prisma.passPolicy.findUnique({ where: { id: policyId } });
      if (policy) {
        happyMoneyPrice = policy.happyMoneyPrice ?? null;
        alternateCtaHappyMoneyPurchase = policy.happyMoneyPrice != null;
      }
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          reason,
          fallbackAttachment: serializeAttachment(fallback ?? undefined),
          alternateCtaHappyMoneyPurchase,
          happyMoneyPrice,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/open-pass/reward-failed] 실패:", e);
    return NextResponse.json(
      { success: false, error: "실패 처리 중 오류가 발생했습니다." },
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
