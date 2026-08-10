// [관상 AI프롬프트 실연동] 관상 히스토리 조회 API — name/history/route.ts와 동일한 패턴.
// Flutter FaceRepository.getHistory()가 지금까지는 로컬 인메모리 리스트만 반환했으나
// (앱 재시작 시 소실), 서버 영속 이력을 조회할 수 있도록 추가한다.
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
    const requests = await prisma.fortuneRequest.findMany({
      where: { userId, fortuneType: "face", deletedAt: null },
      include: { result: true },
      orderBy: { createdAt: "desc" },
    });

    const data = requests
      .filter((r) => r.result)
      .map((r) => {
        let meta: { features?: Record<string, string>; topicResults?: Record<string, string>; summary?: string } = {};
        try {
          meta = r.result?.resultMeta ? JSON.parse(r.result.resultMeta) : {};
        } catch {
          meta = {};
        }
        return {
          id: `face_${r.id}`,
          features: meta.features ?? {},
          topicResults: meta.topicResults ?? {},
          summary: meta.summary ?? r.result?.resultText ?? "",
          createdAt: r.createdAt.toISOString(),
        };
      });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/fortune/face/history] 실패:", e);
    return NextResponse.json(
      { success: false, error: "관상 이력 조회 중 오류가 발생했습니다." },
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
