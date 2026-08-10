// 공개(비인증) "AI 관상" 분석 API — 신규 구현.
//
// [범위 결정 - 관상/손금 AI프롬프트 실연동] completeText()는 텍스트 전용 LLM 호출이라
// 실제 업로드된 얼굴 사진을 인식/분석할 수 없다. 따라서 "사진 촬영 UI는 그대로 유지"하되
// (개인정보보호 원칙상 이미지는 어차피 서버로 전송되지 않고 클라이언트에서 즉시 파기됨),
// 백엔드는 사용자 프로필(생년월일/성별) 등 텍스트 정보를 기반으로 해석 텍스트를 생성한다.
//
// [부위별 특징(features) vs 주제별 해석(topicResults/summary) 분리]
// - features(이마/눈/코/입/턱): 이미지 인식이 전제된 항목이라 completeText()로 대체할 수
//   없다. 기존 Flutter Mock과 동일하게 결정론적 시드 기반 하드코딩 풀에서 선택한다.
// - topicResults(재물/애정/직업/건강) + summary(종합): saju/route.ts와 동일한 패턴으로
//   face 도메인 활성 프롬프트 템플릿 + completeText()를 호출해 실제 LLM 생성 텍스트로
//   교체한다. 템플릿이 없거나 LLM 호출이 실패하면 기존 하드코딩 텍스트로 폴백한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const FEATURE_POOL: Record<string, string[]> = {
  이마: ["넓고 둥근 이마로 지혜와 포용력을 나타냅니다", "반듯한 이마로 계획적이고 신중한 성향을 보여줍니다"],
  눈: ["또렷하고 생기있는 눈매로 총명한 기운이 느껴집니다", "온화한 눈빛으로 주변에 신뢰감을 줍니다"],
  코: ["곧고 균형잡힌 코로 재물운이 안정적입니다", "콧대가 뚜렷해 자립심과 추진력이 강합니다"],
  입: ["단정한 입매로 언행에 신중함이 느껴집니다", "입꼬리가 살짝 올라가 있어 긍정적인 기운이 강합니다"],
  턱: ["둥근 턱선으로 온화하고 사교적인 성향입니다", "단단한 턱선으로 강한 의지와 인내심을 보여줍니다"],
};

const TOPIC_FALLBACK: Record<string, string> = {
  재물: "코와 이마의 조화가 좋아 안정적인 재물운을 타고났습니다. 꾸준한 노력이 결실로 이어질 것입니다.",
  애정: "눈매와 입매에서 따뜻한 기운이 느껴지며, 주변 사람들과 좋은 관계를 맺는 데 유리한 인상입니다.",
  직업: "전체적으로 균형잡힌 인상으로, 리더십과 신뢰를 동시에 얻을 수 있는 관상입니다.",
  건강: "혈색과 윤곽이 안정적이라 전반적인 건강 기운이 양호한 편입니다. 다만 무리한 스케줄은 주의하세요.",
  종합: "전체적으로 조화롭고 안정적인 인상으로, 스스로의 강점을 잘 살리면 좋은 흐름을 이어갈 수 있습니다.",
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

    // 2) 부위별 특징(features)은 이미지 인식이 전제된 항목이라 결정론적 시뮬레이션 유지
    const features: Record<string, string> = {};
    for (const [part, options] of Object.entries(FEATURE_POOL)) {
      features[part] = options[seed % options.length];
    }

    // 3) face 도메인 활성 프롬프트 템플릿 조회 + 주제별 completeText() 호출(트랜잭션 밖)
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "face", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    const topicResults: Record<string, string> = {};
    let usedAi = false;
    for (const topic of TOPICS) {
      const fallback = TOPIC_FALLBACK[topic];
      if (!template) {
        topicResults[topic] = fallback;
        continue;
      }
      const userPrompt = [
        `사용자 생년월일: ${birthDate ?? "미상"}`,
        `성별: ${gender ?? "미상"}`,
        `부위별 인상 특징: 이마(${features["이마"]}), 눈(${features["눈"]}), 코(${features["코"]}), 입(${features["입"]}), 턱(${features["턱"]})`,
        `요청 주제: ${topic}`,
        "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 사람의 관상을 주제에 맞춰 해석해주세요.",
      ].join("\n");
      try {
        topicResults[topic] = await completeText({ systemPrompt: template.templateBody, userPrompt });
        usedAi = true;
      } catch (e) {
        if (e instanceof LlmClientError) {
          console.error(`[POST /api/public/fortune/face] LLM 호출 실패(topic=${topic}):`, e.message);
        } else {
          console.error(`[POST /api/public/fortune/face] LLM 호출 실패(topic=${topic}):`, e);
        }
        topicResults[topic] = fallback;
      }
    }
    const summary = topicResults["종합"] ?? TOPIC_FALLBACK["종합"];

    // 4) 짧은 DB 트랜잭션: fortune_requests·results 기록(포인트 차감 없음, name/route.ts와 동일)
    const outcome = await prisma.$transaction(async (tx) => {
      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "face",
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
              resultMeta: JSON.stringify({ features, topicResults, summary }),
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
          id: `face_${outcome.requestId}`,
          features,
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
      console.error("[POST /api/public/fortune/face] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/face] 실패:", e);
    return NextResponse.json(
      { success: false, error: "관상 분석 중 오류가 발생했습니다." },
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
