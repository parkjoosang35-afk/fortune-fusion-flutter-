// [신통방통 오늘의 운세 — 2026-11 AI 무당체 전환] 지난 결과 목록.
// "GET /api/fortune/{kind}/history?limit=6" — 아카이브 리스트 데이터 소스.
// 조회 전용 — 어떤 경우에도 새로 생성하지 않는다.
// [주간/월간 삭제] kind는 "today" 하나만 유효.
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
  { params }: { params: Promise<{ kind: string }> }
) {
  const { kind: rawKind } = await params;
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

  const limitParam = Number(request.nextUrl.searchParams.get("limit") ?? "6");
  const limit = Number.isFinite(limitParam) && limitParam > 0 ? Math.min(limitParam, 20) : 6;

  try {
    const rows = await prisma.fortunePeriodResult.findMany({
      where: { userId: payload.userId, kind, invalidated: false },
      orderBy: { createdAt: "desc" },
      take: limit,
      select: { periodKey: true, payload: true, createdAt: true, sajuRev: true },
    });

    const items = rows.map((row) => {
      const data = JSON.parse(row.payload) as FortunePayload;
      return {
        periodKey: row.periodKey,
        headline: data.headline,
        createdAt: row.createdAt.toISOString(),
      };
    });

    return NextResponse.json({ success: true, data: { kind, items } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error(`[GET /api/public/fortune-period/${kind}/history] 실패:`, e);
    return NextResponse.json(
      { success: false, error: "지난 운세 목록을 불러오는 중 오류가 발생했습니다." },
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
