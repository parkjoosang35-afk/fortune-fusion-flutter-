// 공개(비인증) 복주머니 광고 목록 API — Flutter 복주머니 화면의 "광고 보기" 카드가
// 노출할 광고 목록을 조회한다. [신통방통 복주머니 광고 적립 시스템]
// 노출조건(isActive/status/기간)을 만족하는 광고만 priority 오름차순으로 반환하며,
// userId가 주어지면 각 광고별 오늘 시청현황(today-status)을 함께 병합한다.
// wallet/route.ts와 동일하게 userId를 query로 받는다(로그인 시스템 미완성 임시방편).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { todayRangeKst } from "@/lib/luck-pouch-engine";
import { serializeFortuneAdSummary } from "@/lib/fortune-ad-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const userId = Number(request.nextUrl.searchParams.get("userId") ?? 1);

  try {
    const now = new Date();
    const ads = await prisma.fortuneAd.findMany({
      where: {
        deletedAt: null,
        isActive: true,
        status: "active",
        OR: [{ startAt: null }, { startAt: { lte: now } }],
      },
      orderBy: [{ priority: "asc" }, { id: "asc" }],
    });
    // endAt은 OR 조건과 함께 쓰기 까다로워 애플리케이션 레벨에서 한 번 더 필터링한다.
    const visibleAds = ads.filter((ad) => !ad.endAt || ad.endAt >= now);

    const { start, end } = todayRangeKst();
    const [userLogs, allLogs] = await Promise.all([
      prisma.fortuneAdWatchLog.findMany({
        where: {
          adId: { in: visibleAds.map((a) => a.id) },
          userId,
          rewardStatus: "COMPLETED",
          createdAt: { gte: start, lt: end },
        },
        select: { adId: true },
      }),
      prisma.fortuneAdWatchLog.findMany({
        where: {
          adId: { in: visibleAds.map((a) => a.id) },
          rewardStatus: "COMPLETED",
          createdAt: { gte: start, lt: end },
        },
        select: { adId: true, rewardAmount: true },
      }),
    ]);
    const userCountMap = new Map<number, number>();
    for (const log of userLogs) {
      userCountMap.set(log.adId, (userCountMap.get(log.adId) ?? 0) + 1);
    }
    const totalRewardMap = new Map<number, number>();
    for (const log of allLogs) {
      totalRewardMap.set(log.adId, (totalRewardMap.get(log.adId) ?? 0) + log.rewardAmount);
    }

    const data = visibleAds.map((ad) => {
      const todayUserCount = userCountMap.get(ad.id) ?? 0;
      const todayTotalReward = totalRewardMap.get(ad.id) ?? 0;
      const perUserRemaining = Math.max(0, ad.perUserDailyLimit - todayUserCount);
      const rewardRemaining =
        ad.dailyLimitReward != null ? Math.max(0, ad.dailyLimitReward - todayTotalReward) : null;
      const watchable = perUserRemaining > 0 && (rewardRemaining == null || rewardRemaining > 0);

      return {
        ...serializeFortuneAdSummary(ad),
        todayWatchedCount: todayUserCount,
        todayRemainingCount: perUserRemaining,
        watchable,
      };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/ads/fortune] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 목록 조회 중 오류가 발생했습니다." },
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
