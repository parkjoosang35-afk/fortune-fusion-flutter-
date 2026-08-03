// [운세 카테고리 확장 - 남은 미세조정] 타로 히스토리 조회 API.
//
// Flutter TarotRepository.getHistory()가 지금까지는 로컬 인메모리 리스트만
// 반환했으나(앱 재시작 시 소실), 궁합(compatibility/history)과 동일한 패턴을
// 재사용해 서버 영속 이력을 조회할 수 있도록 추가한다.
//
// [스키마 확인] POST /api/public/fortune/tarot는 spreadType(one_card/
// three_card/yes_no)과 무관하게 FortuneRequest.fortuneType을 항상 "tarot"
// 문자열로 저장한다(도메인 분기는 ai_prompt_templates 조회에만 쓰이고
// 저장값에는 영향 없음). 따라서 조회 시 fortuneType: "tarot" 단일 조건으로
// 모든 스프레드(YES/NO 포함)를 포괄한다.
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
      where: { userId, fortuneType: "tarot", deletedAt: null },
      include: { result: true },
      orderBy: { createdAt: "desc" },
    });

    const data = requests
      .filter((r) => r.result)
      .map((r) => {
        let input: { question?: string; spreadType?: string; topic?: string } = {};
        try {
          input = r.inputPayload ? JSON.parse(r.inputPayload) : {};
        } catch {
          input = {};
        }
        let meta: { positions?: unknown[]; answer?: string | null } = {};
        try {
          meta = r.result?.resultMeta ? JSON.parse(r.result.resultMeta) : {};
        } catch {
          meta = {};
        }
        return {
          id: `tarot_${r.id}`,
          question: input.question ?? "",
          spreadType: input.spreadType ?? "one_card",
          topic: input.topic ?? "general",
          positions: meta.positions ?? [],
          answer: meta.answer ?? null,
          summary: r.result?.resultText ?? "",
          createdAt: r.createdAt.toISOString(),
        };
      });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/fortune/tarot/history] 실패:", e);
    return NextResponse.json(
      { success: false, error: "타로 이력 조회 중 오류가 발생했습니다." },
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
