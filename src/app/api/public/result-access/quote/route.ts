// 공개(인증 필요) "결과보기 권한 선택 화면" 상태 조회 API.
// [결과보기 통합 권한 시스템 v1.0] §6 결과보기 클릭 시 사용자 상태에 따라 3택 UI를
// 그려야 하므로, Flutter가 이 화면을 열기 전에 먼저 호출해 프리패스/복주머니/광고
// 가용 상태를 한 번에 받아온다. 실제 차감은 절대 하지 않는다(조회 전용).
import { NextRequest, NextResponse } from "next/server";
import { getResultAccessQuote } from "@/lib/result-access-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

  const { searchParams } = new URL(request.url);
  const contentType = searchParams.get("contentType") ?? "unknown";
  const categoryKey = searchParams.get("categoryKey");

  try {
    const quote = await getResultAccessQuote(userId, contentType, categoryKey);
    return NextResponse.json({ success: true, data: quote }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/result-access/quote] 실패:", e);
    return NextResponse.json(
      { success: false, error: "권한 정보를 조회하는 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
