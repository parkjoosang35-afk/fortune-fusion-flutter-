// 공개(비인증) 궁합 요청 이력 조회 API — Flutter CompatibilityRepository.getHistory() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const requests = await prisma.compatibilityRequest.findMany({
      where: { requesterUserId: userId, deletedAt: null },
      include: { result: true },
      orderBy: { createdAt: "desc" },
    });

    const data = requests
      .filter((r) => r.result)
      .map((r) => {
        let targetInput: { nameA?: string; nameB?: string } = {};
        try {
          targetInput = r.targetInput ? JSON.parse(r.targetInput) : {};
        } catch {
          targetInput = {};
        }
        let detail: { topicResults?: Record<string, string>; summary?: string } = {};
        try {
          detail = r.result ? JSON.parse(r.result.detail) : {};
        } catch {
          detail = {};
        }
        return {
          id: `compat_${r.id}`,
          nameA: targetInput.nameA ?? "나",
          nameB: targetInput.nameB ?? "상대방",
          type: r.type,
          score: r.result?.score ?? 0,
          topicResults: detail.topicResults ?? {},
          summary: detail.summary ?? "",
          createdAt: r.createdAt.toISOString(),
        };
      });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/compatibility/history] 실패:", e);
    return NextResponse.json(
      { success: false, error: "궁합 이력을 불러오지 못했습니다." },
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
