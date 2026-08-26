// 공개(비인증) 상담 세션용 "광고 시청 성공 → 시청기록 발급" API —
// Flutter OpenPassRewardController.watchAdAndClaim()과 동일한 흐름을 상담 세션에
// 적용하되, 기존 /api/public/open-pass/reward-complete와는 달리 PassPolicy/UserPass를
// 전혀 만들지 않는다(§15: 상담은 사주/타로 프리패스와 완전히 독립된 예산이므로,
// "광고를 봤다"는 사실 자체(OpenPassAdRewardLog)만 남기면 충분하다).
//
// 여기서 발급되는 OpenPassAdRewardLog.id가 곧 상담 세션 생성 API
// (POST /api/public/consultation/session)가 요구하는 adRewardLogId다.
// checkAdRewardEligibility/recordAdRewardLog는 open-pass-service.ts의 단일 소스를
// 그대로 재사용해 쿨다운/일일한도 판정 로직이 앱 전체에서 갈라지지 않게 한다.
import { NextRequest, NextResponse } from "next/server";
import { checkAdRewardEligibility, recordAdRewardLog } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

interface AdRewardCompleteBody {
  userId?: number;
  adSourceId?: number;
}

export async function POST(request: NextRequest) {
  let body: AdRewardCompleteBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 0);
  const adSourceId = Number(body.adSourceId ?? 0);

  if (!userId || !adSourceId) {
    return NextResponse.json(
      { success: false, error: "userId, adSourceId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const eligibility = await checkAdRewardEligibility(userId, adSourceId);
    if (!eligibility.eligible) {
      const reasonLabel: Record<string, string> = {
        AD_SOURCE_NOT_FOUND: "존재하지 않는 광고소스입니다.",
        AD_SOURCE_INACTIVE: "현재 비활성화된 광고소스입니다.",
        AD_SOURCE_NOT_STARTED: "아직 노출 시작 전인 광고소스입니다.",
        AD_SOURCE_ENDED: "노출 기간이 종료된 광고소스입니다.",
        COOLDOWN: "쿨다운 시간이 남아있습니다.",
        DAILY_LIMIT_REACHED: "오늘의 시청 가능 횟수를 모두 사용했습니다.",
      };
      return NextResponse.json(
        {
          success: false,
          error: reasonLabel[eligibility.reason] ?? "지금은 보상을 받을 수 없습니다.",
          reason: eligibility.reason,
          ...("cooldownRemainingSec" in eligibility
            ? { cooldownRemainingSec: eligibility.cooldownRemainingSec }
            : {}),
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    // PassPolicy/UserPass 없이 "시청 성공" 원장만 남긴다 — passPolicyId/userPassId 모두 null.
    const log = await recordAdRewardLog({
      userId,
      adSourceId,
      passPolicyId: null,
      result: "success",
      rewardGranted: true,
      userPassId: null,
    });

    return NextResponse.json(
      { success: true, data: { adRewardLogId: log.id } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/consultation/ad-reward-complete] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 시청 기록 처리 중 오류가 발생했습니다." },
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
