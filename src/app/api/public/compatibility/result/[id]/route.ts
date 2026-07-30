// 공개(비인증) 궁합 결과 단건 조회 API — Flutter CompatibilityRepository.getResultById() 대응.
// id는 "compat_{requestId}" 형식(Flutter 표시용 접두사) 또는 순수 숫자 모두 허용.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseRequestId(raw: string): number | null {
  const m = raw.match(/^compat_(\d+)$/) ?? raw.match(/^(\d+)$/);
  if (!m) return null;
  return Number(m[1]);
}

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const requestId = parseRequestId(id);
  if (requestId == null) {
    return NextResponse.json(
      { success: false, error: "id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const compatRequest = await prisma.compatibilityRequest.findFirst({
      where: { id: requestId, deletedAt: null },
      include: { result: true },
    });
    if (!compatRequest || !compatRequest.result) {
      return NextResponse.json(
        { success: false, error: "결과를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    let targetInput: { nameA?: string; nameB?: string } = {};
    try {
      targetInput = compatRequest.targetInput ? JSON.parse(compatRequest.targetInput) : {};
    } catch {
      targetInput = {};
    }
    let detail: { topicResults?: Record<string, string>; summary?: string } = {};
    try {
      detail = JSON.parse(compatRequest.result.detail);
    } catch {
      detail = {};
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `compat_${compatRequest.id}`,
          nameA: targetInput.nameA ?? "나",
          nameB: targetInput.nameB ?? "상대방",
          type: compatRequest.type,
          score: compatRequest.result.score,
          topicResults: detail.topicResults ?? {},
          summary: detail.summary ?? "",
          createdAt: compatRequest.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/compatibility/result/[id]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "궁합 결과를 불러오지 못했습니다." },
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
