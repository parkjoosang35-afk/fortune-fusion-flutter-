// [운세 카테고리 확장 - 남은 미세조정] 이름 운세(성명학) 히스토리 조회 API.
//
// Flutter NameFortuneRepository.getHistory()가 지금까지는 로컬 인메모리
// 리스트만 반환했으나(앱 재시작 시 소실), 궁합(compatibility/history)과
// 동일한 패턴을 그대로 재사용해 서버 영속 이력을 조회할 수 있도록 추가한다.
//
// [스키마 차이] 궁합은 전용 CompatibilityRequest/Result 테이블을 쓰지만,
// 이름 운세는 사주/타로와 동일한 공용 FortuneRequest/FortuneResult 테이블을
// `fortuneType: "name"`으로 구분해 사용한다(POST /api/public/fortune/name
// 참고). 따라서 조회 조건도 그에 맞춰 조정한다.
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
      where: { userId, fortuneType: "name", deletedAt: null },
      include: { result: true },
      orderBy: { createdAt: "desc" },
    });

    const data = requests
      .filter((r) => r.result)
      .map((r) => {
        let input: { name?: string; hanja?: string; birthDate?: string; gender?: string } = {};
        try {
          input = r.inputPayload ? JSON.parse(r.inputPayload) : {};
        } catch {
          input = {};
        }
        return {
          id: `name_${r.id}`,
          name: input.name ?? "",
          hanja: input.hanja ?? null,
          birthDate: input.birthDate ?? null,
          gender: input.gender ?? null,
          resultText: r.result?.resultText ?? "",
          createdAt: r.createdAt.toISOString(),
        };
      });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/fortune/name/history] 실패:", e);
    return NextResponse.json(
      { success: false, error: "이름 운세 이력 조회 중 오류가 발생했습니다." },
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
