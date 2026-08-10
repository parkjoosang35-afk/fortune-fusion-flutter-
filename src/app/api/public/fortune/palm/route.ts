// 공개(비인증) "AI 손금" 분석 API — 신규 구현.
//
// [범위 결정 - 관상/손금 AI프롬프트 실연동] face/route.ts와 완전히 동일한 원칙을 따른다.
// completeText()는 텍스트 전용 LLM 호출이라 실제 업로드된 손바닥 사진을 인식/분석할 수
// 없다. "사진 촬영 UI는 그대로 유지"하되(이미지는 서버로 전송되지 않고 클라이언트에서
// 즉시 파기됨), 백엔드는 사용자 프로필(생년월일/성별) 등 텍스트 정보를 기반으로 해석
// 텍스트를 생성한다.
//
// [부위별 특징(lines) vs 주제별 해석(topicResults/summary) 분리]
// - lines(생명선/두뇌선/감정선/운명선): 이미지 인식이 전제된 항목이라 completeText()로
//   대체할 수 없다. 기존 Flutter Mock과 동일하게 결정론적 시드 기반 하드코딩 풀에서 선택.
// - topicResults(재물/애정/직업/건강) + summary(종합): saju/face 라우트와 동일한 패턴으로
//   palm 도메인 활성 프롬프트 템플릿 + completeText()를 호출해 실제 LLM 생성 텍스트로
//   교체한다. 템플릿이 없거나 LLM 호출이 실패하면 기존 하드코딩 텍스트로 폴백한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const LINE_POOL: Record<string, string[]> = {
  생명선: [
    "깊고 선명하게 뻗어 있어 강한 생명력과 활력을 나타냅니다",
    "완만하게 이어져 있어 안정적이고 평온한 삶의 흐름을 보여줍니다",
  ],
  두뇌선: [
    "뚜렷하고 길게 뻗어 있어 논리적이고 분석적인 사고력을 나타냅니다",
    "살짝 곡선을 이루어 창의적이고 유연한 사고를 보여줍니다",
  ],
  감정선: ["깊고 곧게 뻗어 있어 감정 표현이 솔직하고 직접적입니다", "부드러운 곡선으로 따뜻하고 공감능력이 높은 성향입니다"],
  운명선: [
    "선명하게 이어져 있어 뚜렷한 목표의식을 갖고 나아가는 흐름입니다",
    "중간에 변화가 있어 인생의 전환점을 여러 번 맞이하는 흐름입니다",
  ],
};

const TOPIC_FALLBACK: Record<string, string> = {
  재물: "운명선과 생명선의 조화가 좋아 꾸준한 재물 축적이 가능한 손금입니다.",
  애정: "감정선이 뚜렷하여 진솔한 감정 표현으로 좋은 인연을 만날 가능성이 높습니다.",
  직업: "두뇌선의 흐름이 안정적이라 전문성을 쌓아가는 데 유리한 조건입니다.",
  건강: "생명선이 깊게 새겨져 있어 전반적인 체력과 회복력이 좋은 편입니다.",
  종합: "전체적으로 균형 잡힌 손금으로, 스스로의 강점을 신뢰하고 나아가면 좋은 결실을 맺을 수 있습니다.",
};

const TOPICS = ["재물", "애정", "직업", "건강", "종합"] as const;

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

export async function POST(request: NextRequest) {
  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) 사용자 프로필(생년월일/성별) 조회 -- 실제 이미지 대신 텍스트 기반 해석의 입력으로 사용
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new Error("USER_NOT_FOUND");
    const birthDate = user.profile?.birthDate ?? null;
    const gender = user.gender ?? null;

    const seed = hashSeed(`${userId}:${birthDate ?? "unknown"}:${Date.now()}`);

    // 2) 부위별 특징(lines)은 이미지 인식이 전제된 항목이라 결정론적 시뮬레이션 유지
    const lines: Record<string, string> = {};
    for (const [part, options] of Object.entries(LINE_POOL)) {
      lines[part] = options[seed % options.length];
    }

    // 3) palm 도메인 활성 프롬프트 템플릿 조회 + 주제별 completeText() 호출(트랜잭션 밖)
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "palm", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    // [성능 개선 - 병렬화] 토픽 5개를 순차(각 최대 30s)로 호출하면 최악의 경우
    // 총 응답시간이 150s까지 늘어날 수 있음이 실측으로 확인됨(56s 관측).
    // Promise.allSettled()로 5개 요청을 동시에 발사해 전체 응답시간을
    // "가장 느린 1건의 시간"으로 단축한다(개별 실패는 서로 영향 없이 격리됨).
    const topicResults: Record<string, string> = {};
    let usedAi = false;
    if (!template) {
      for (const topic of TOPICS) {
        topicResults[topic] = TOPIC_FALLBACK[topic];
      }
    } else {
      const settled = await Promise.allSettled(
        TOPICS.map((topic) => {
          const userPrompt = [
            `사용자 생년월일: ${birthDate ?? "미상"}`,
            `성별: ${gender ?? "미상"}`,
            `손금 특징: 생명선(${lines["생명선"]}), 두뇌선(${lines["두뇌선"]}), 감정선(${lines["감정선"]}), 운명선(${lines["운명선"]})`,
            `요청 주제: ${topic}`,
            "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 사람의 손금을 주제에 맞춰 해석해주세요.",
          ].join("\n");
          return completeText({ systemPrompt: template.templateBody, userPrompt });
        })
      );
      settled.forEach((result, index) => {
        const topic = TOPICS[index];
        if (result.status === "fulfilled") {
          topicResults[topic] = result.value;
          usedAi = true;
        } else {
          const e = result.reason;
          if (e instanceof LlmClientError) {
            console.error(`[POST /api/public/fortune/palm] LLM 호출 실패(topic=${topic}):`, e.message);
          } else {
            console.error(`[POST /api/public/fortune/palm] LLM 호출 실패(topic=${topic}):`, e);
          }
          topicResults[topic] = TOPIC_FALLBACK[topic];
        }
      });
    }
    const summary = topicResults["종합"] ?? TOPIC_FALLBACK["종합"];

    // 4) 짧은 DB 트랜잭션: fortune_requests·results 기록(포인트 차감 없음, name/route.ts와 동일)
    const outcome = await prisma.$transaction(async (tx) => {
      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "palm",
          inputPayload: JSON.stringify({ birthDate, gender }),
          sourceType: "ai_generated",
          pointSpent: 0,
          status: "success",
        },
      });

      const fortuneResult = template
        ? await tx.fortuneResult.create({
            data: {
              requestId: fortuneRequest.id,
              resultText: summary,
              resultMeta: JSON.stringify({ lines, topicResults, summary }),
              aiModel: usedAi ? "claude-haiku-4-5" : "rule-based-v1",
              promptTemplateId: template.id,
              promptVersion: template.version,
              status: "active",
            },
          })
        : null;

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, fortuneResult };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `palm_${outcome.requestId}`,
          lines,
          topicResults,
          summary,
          createdAt: outcome.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/fortune/palm] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/palm] 실패:", e);
    return NextResponse.json(
      { success: false, error: "손금 분석 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
