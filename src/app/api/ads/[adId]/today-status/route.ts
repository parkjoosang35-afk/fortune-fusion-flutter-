// 공개(비인증) 복주머니 광고 오늘 현황 조회 API — Flutter 화면의 "오늘 N/M회" 표시,
// 그리고 시청 다이얼로그를 열기 전 사전 자격 확인(빠른 실패)에 사용한다.
// [신통방통 복주머니 광고 적립 시스템] checkFortuneAdEligibility()를 단일 소스로 사용해
// 관리자 설정(회원당 하루 시청 횟수/광고당 하루 최대 지급량)과 실제 판정이 갈라지지 않게 한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkFortuneAdEligibility, FORTUNE_AD_REASON_LABELS } from "@/lib/fortune-ad-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest, context: { params: Promise<{ adId: string }> }) {
  const { adId: adIdParam } = await context.params;
  const adId = Number(adIdParam);
  const userId = Number(request.nextUrl.searchParams.get("userId") ?? 1);

  if (!Number.isInteger(adId) || adId <= 0) {
    return NextResponse.json(
      { success: false, error: "올바르지 않은 광고 ID입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const ad = await prisma.fortuneAd.findUnique({ where: { id: adId } });
    if (!ad || ad.deletedAt) {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 광고입니다.", reason: "AD_NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const eligibility = await checkFortuneAdEligibility(adId, userId);
    const perUserRemaining = Math.max(0, ad.perUserDailyLimit - eligibility.todayUserCount);
    const rewardRemaining =
      ad.dailyLimitReward != null ? Math.max(0, ad.dailyLimitReward - eligibility.todayTotalReward) : null;

    return NextResponse.json(
      {
        success: true,
        data: {
          adId: ad.id,
          watchable: eligibility.eligible,
          reason: eligibility.reason ?? null,
          reasonLabel: eligibility.reason ? FORTUNE_AD_REASON_LABELS[eligibility.reason] : null,
          todayWatchedCount: eligibility.todayUserCount,
          perUserDailyLimit: ad.perUserDailyLimit,
          todayRemainingCount: perUserRemaining,
          dailyLimitReward: ad.dailyLimitReward,
          todayTotalReward: eligibility.todayTotalReward,
          rewardRemaining,
          rewardAmount: ad.rewardAmount,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/ads/[adId]/today-status] 실패:", e);
    return NextResponse.json(
      { success: false, error: "현황 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
