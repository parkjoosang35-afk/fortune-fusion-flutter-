// 공개(비인증) 행운상자 오늘 현황 조회 API — Flutter 복주머니 탭이 그리드
// 화면을 그릴 때 "오늘 N/5회" 표시와 CTA 활성화 여부를 결정하는 데 쓴다.
// [행운상자 - 복주머니 탭 신규 기능] checkPouchBoxEligibility()를 단일
// 소스로 사용해 실제 시청 판정과 이 화면 표시가 갈라지지 않게 한다.
import { NextRequest, NextResponse } from "next/server";
import { checkPouchBoxEligibility, POUCH_BOX_REASON_LABELS } from "@/lib/pouch-box-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const userId = Number(request.nextUrl.searchParams.get("userId") ?? 1);

  try {
    const eligibility = await checkPouchBoxEligibility(userId);
    return NextResponse.json(
      {
        success: true,
        data: {
          dailyLimit: eligibility.dailyLimit,
          todayOpenedCount: eligibility.todayOpenedCount,
          dailyLeft: eligibility.dailyLeft,
          watchable: eligibility.eligible,
          reason: eligibility.reason ?? null,
          reasonLabel: eligibility.reason ? POUCH_BOX_REASON_LABELS[eligibility.reason] : null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/pouch-box/state] 실패:", e);
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
