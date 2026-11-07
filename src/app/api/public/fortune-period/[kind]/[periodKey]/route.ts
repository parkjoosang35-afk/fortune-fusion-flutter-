// [신통방통 오늘의 운세 — 2026-11 AI 무당체 전환] 과거 특정 기간 결과 조회.
// "GET /api/fortune/{kind}/{periodKey} (view past result, never generates)" —
// PastBanner "지난 운세 다시 보기" 클릭 시 사용. 이 라우트는 절대 새로
// 생성하지 않는다(조회만, 없으면 404). [주간/월간 삭제] kind는 "today" 하나만.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest } from "@/lib/user-auth";
import type { FortuneKind } from "@/lib/fortune-period/period-key";
import type { FortunePayload } from "@/lib/fortune-period/engine-adapter";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function isValidKind(v: string): v is FortuneKind {
  return v === "today";
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ kind: string; periodKey: string }> }
) {
  const { kind: rawKind, periodKey } = await params;
  if (rawKind === "week" || rawKind === "month") {
    return NextResponse.json(
      {
        success: false,
        error: "주간/월간 운세는 더 이상 제공하지 않아요.",
        reason: "GONE",
      },
      { status: 410, headers: CORS_HEADERS }
    );
  }
  if (!isValidKind(rawKind)) {
    return NextResponse.json(
      { success: false, error: "지원하지 않는 운세 종류입니다.", reason: "INVALID_KIND" },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const kind = rawKind;

  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "로그인이 필요합니다.", reason: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  try {
    // [sajuRev 무관 최신 1건] 과거 결과 열람은 "그 시점에 어떤 사주리비전으로
    // 생성됐든" 보관 기록을 그대로 보여주는 것이 목적이므로(README §4 "지난
        // 기간 결과는 보관 기록으로 그대로 둔다"), periodKey만으로 조회하고
    // sajuRev 조건은 걸지 않는다 — 혹시 같은 periodKey에 여러 리비전이
    // 쌓여 있어도(과거엔 드묾) 가장 최근 생성분을 보여준다.
    const row = await prisma.fortunePeriodResult.findFirst({
      where: { userId: payload.userId, kind, periodKey },
      orderBy: { createdAt: "desc" },
    });

    if (!row) {
      return NextResponse.json(
        { success: false, error: "해당 기간의 운세를 찾을 수 없어요.", reason: "RESULT_NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const data = JSON.parse(row.payload) as FortunePayload;
    return NextResponse.json(
      {
        success: true,
        data: {
          kind,
          periodKey: row.periodKey,
          headline: data.headline,
          text: data.text,
          dayGanZhi: data.dayGanZhi,
          luckyColor: data.luckyColor,
          luckyDirection: data.luckyDirection,
          luckyNumber: data.luckyNumber,
          source: data.source,
          isPast: true,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error(`[GET /api/public/fortune-period/${kind}/${periodKey}] 실패:`, e);
    return NextResponse.json(
      { success: false, error: "운세를 불러오는 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
