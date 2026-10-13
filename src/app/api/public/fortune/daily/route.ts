// 2026-08-13 앱 정본: 일간 운세는 정통사주 80항목으로 통합.
// 구 API는 기존 결과 조회만 제공한다. 신규 생성·LLM 호출·보너스/미션 지급 없음.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const rawId = request.nextUrl.searchParams.get("requestId");
  const idMatch = rawId == null ? null : /^(?:df_)?([1-9]\d*)$/.exec(rawId);
  if (rawId != null && (!idMatch || !Number.isSafeInteger(Number(idMatch[1])))) {
    return NextResponse.json({ success: false, error: "조회할 결과 번호를 확인해주세요.", reason: "INVALID_REQUEST_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const now = new Date();
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const start = new Date(Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate()) - 9 * 60 * 60 * 1000);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  try {
    const saved = await prisma.fortuneRequest.findFirst({
      where: { userId: auth.userId, fortuneType: "daily", status: "success", deletedAt: null,
        result: { is: { deletedAt: null } },
        ...(idMatch ? { id: Number(idMatch[1]) } : { createdAt: { gte: start, lt: end } }),
      }, include: { result: true }, orderBy: { createdAt: "desc" },
    });
    if (!saved?.result) {
      return NextResponse.json({ success: false, reason: idMatch ? "RESULT_NOT_FOUND" : "DAILY_FORTUNE_INTEGRATED",
        error: idMatch ? "저장된 일간 운세를 찾을 수 없습니다." : "일간 운세는 정통사주 80항목으로 통합되었습니다.",
        redirectRoute: "/saju-renewal" }, { status: idMatch ? 404 : 410, headers: CORS_HEADERS });
    }
    const meta = saved.result.resultMeta ? JSON.parse(saved.result.resultMeta) : {};
    return NextResponse.json({ success: true, data: {
      id: `df_${saved.id}`, date: saved.createdAt.toISOString(), categoryScores: meta.categoryScores ?? {},
      luckyColor: meta.luckyColor ?? "", luckyNumber: meta.luckyNumber ?? null,
      summaryText: saved.result.resultText, alreadyGenerated: true, readOnly: true,
      refundAmount: 0, balance: null, missionUpdates: [], firstViewBonus: 0,
    } }, { headers: CORS_HEADERS });
  } catch (error) {
    console.error("[GET /api/public/fortune/daily] 기존 결과 조회 실패:", error);
    return NextResponse.json({ success: false, error: "기존 일간 운세 조회 중 오류가 발생했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}
export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: { ...CORS_HEADERS, "Access-Control-Allow-Methods": "GET, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, Authorization" } });
}
