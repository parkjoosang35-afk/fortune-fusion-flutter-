// 공개(비인증) 복주머니 광고 시청 시작 API — Flutter 광고 시청 팝업의 "시작" 단계.
// [신통방통 복주머니 광고 적립 시스템] 자격(checkFortuneAdEligibility)을 확인한 뒤
// FortuneAdWatchLog를 PENDING 상태로 생성해 세션을 발급한다. 실제 지급은 이 시점에
// 이뤄지지 않으며, 클라이언트가 시청을 끝까지 마치고 /complete를 호출해야 지급된다
// (중간에 종료하면 PENDING인 채로 남아 보상이 지급되지 않는다).
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/db";
import { checkFortuneAdEligibility, FORTUNE_AD_REASON_LABELS } from "@/lib/fortune-ad-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest, context: { params: Promise<{ adId: string }> }) {
  const { adId: adIdParam } = await context.params;
  const adId = Number(adIdParam);

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  if (!Number.isInteger(adId) || adId <= 0) {
    return NextResponse.json(
      { success: false, error: "올바르지 않은 광고 ID입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const eligibility = await checkFortuneAdEligibility(adId, userId);
    if (!eligibility.eligible) {
      return NextResponse.json(
        {
          success: false,
          error: eligibility.reason ? FORTUNE_AD_REASON_LABELS[eligibility.reason] : "지금은 시청할 수 없습니다.",
          reason: eligibility.reason,
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    const ad = await prisma.fortuneAd.findUnique({ where: { id: adId } });
    if (!ad) {
      // checkFortuneAdEligibility에서 이미 존재 확인을 하지만, 방어적으로 한 번 더 체크.
      return NextResponse.json(
        { success: false, error: "존재하지 않는 광고입니다.", reason: "AD_NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const sessionId = randomUUID();
    const log = await prisma.fortuneAdWatchLog.create({
      data: {
        userId,
        adId,
        sessionId,
        rewardStatus: "PENDING",
      },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          sessionId: log.sessionId,
          watchLogId: log.id,
          adId: ad.id,
          watchSeconds: ad.watchSeconds,
          rewardAmount: ad.rewardAmount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/ads/[adId]/start] 실패:", e);
    return NextResponse.json(
      { success: false, error: "시청 시작 처리 중 오류가 발생했습니다." },
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
