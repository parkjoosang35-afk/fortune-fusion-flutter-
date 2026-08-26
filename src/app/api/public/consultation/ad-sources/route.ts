// 공개(비인증) 상담 세션용 "광고소스 목록" API — Flutter가 세션 시작 전 광고게이트에
// 노출할 리워드 광고소스를 조회한다. Flutter RewardedAdSimulator/OpenPassAdSourceResolver를
// 그대로 재사용하되(§ 상담 채팅), 사주/타로 프리패스(PassPolicy)와는 완전히 무관하게
// 동작해야 하므로 OpenPassProductAdSource(상품-광고소스 N:M 바인딩) 테이블을 거치지 않고
// OpenPassAdSource를 직접 조회한다 — resolveProductAdConfig()와 형태는 비슷하지만
// policyId 개념이 전혀 없다(§15: 상담과 사주/타로는 독립 예산이므로 로직도 독립시킨다).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkAdRewardEligibility } from "@/lib/open-pass-service";
import { isMockAdSourceType } from "@/lib/open-pass-constants";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userIdParam = searchParams.get("userId");
  const userId = userIdParam ? Number(userIdParam) : undefined;

  try {
    const now = new Date();
    const sources = await prisma.openPassAdSource.findMany({
      where: {
        deletedAt: null,
        isActive: true,
        OR: [{ startAt: null }, { startAt: { lte: now } }],
      },
      orderBy: [{ priority: "asc" }, { id: "asc" }],
    });

    const filtered = sources.filter((s) => !s.endAt || s.endAt >= now);

    const result = [];
    for (const s of filtered) {
      const eligibility = userId ? await checkAdRewardEligibility(userId, s.id) : null;
      result.push({
        adSourceId: s.id,
        sourceName: s.sourceName,
        sourceType: s.sourceType,
        networkName: s.networkName,
        adUnitId: s.adUnitId,
        placementId: s.placementId,
        rewardType: s.rewardType,
        rewardValue: s.rewardValue,
        cooldownSeconds: s.cooldownSeconds,
        dailyLimit: s.dailyLimit,
        testModeEnabled: s.testModeEnabled,
        priority: s.priority,
        eligible: eligibility ? eligibility.eligible : null,
        eligibilityReason: eligibility && !eligibility.eligible ? eligibility.reason : null,
        isMock: isMockAdSourceType(s.sourceType),
        simulatedDurationSeconds: s.simulatedDurationSeconds,
        failMode: s.failMode,
      });
    }

    return NextResponse.json({ success: true, data: { adSources: result } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/consultation/ad-sources] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 정보를 불러오지 못했습니다." },
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
