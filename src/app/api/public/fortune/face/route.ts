// 공개(비인증) "AI 관상" 분석 API — 실사진 분석 버전.
//
// [버그 수정 배경] 기존 구현은 completeText()(텍스트 전용 LLM)만 사용해 실제
// 업로드된 얼굴 사진을 전혀 서버로 전송/분석하지 않고, 로그인 사용자의
// 생년월일/성별 텍스트와 결정론적 시드로 고른 하드코딩 문구만 반환했다.
// 그 결과 손/사물 등 얼굴이 아닌 사진을 올려도 항상 "그럴듯한" 결과가
// 나오는 심각한 문제가 있었다(사용자 리포트로 발견).
//
// [수정 내용] completeVisionJson()으로 실제 이미지(base64 data URL)를 Vision
// 모델(claude-haiku-4-5)에 함께 전송해:
//   1) 사진이 실제로 사람 얼굴인지 먼저 검증하고(valid=false면 즉시 에러 응답),
//   2) 유효한 경우 사진에서 실제로 관찰되는 특징을 근거로 관상 해석을 생성한다.
// 이제 얼굴이 아닌 사진(손/사물/풍경 등)을 올리면 "얼굴 사진이 아닙니다"류의
// 명확한 에러가 반환되고, 포인트/기록도 남기지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeVisionJson, LlmClientError } from "@/lib/llm-client";
import { checkCategoryUsage, consumeCategoryUsage } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const TOPIC_FALLBACK: Record<string, string> = {
  재물: "코와 이마의 조화가 좋아 안정적인 재물운을 타고났습니다. 꾸준한 노력이 결실로 이어질 것입니다.",
  애정: "눈매와 입매에서 따뜻한 기운이 느껴지며, 주변 사람들과 좋은 관계를 맺는 데 유리한 인상입니다.",
  직업: "전체적으로 균형잡힌 인상으로, 리더십과 신뢰를 동시에 얻을 수 있는 관상입니다.",
  건강: "혈색과 윤곽이 안정적이라 전반적인 건강 기운이 양호한 편입니다. 다만 무리한 스케줄은 주의하세요.",
  종합: "전체적으로 조화롭고 안정적인 인상으로, 스스로의 강점을 잘 살리면 좋은 흐름을 이어갈 수 있습니다.",
};

const FEATURE_FALLBACK: Record<string, string> = {
  이마: "이마의 균형이 안정적인 인상입니다.",
  눈: "눈매에서 또렷한 기운이 느껴집니다.",
  코: "코의 균형이 안정적인 인상입니다.",
  입: "입매가 단정한 인상입니다.",
  턱: "턱선이 안정적인 인상입니다.",
};

const SYSTEM_PROMPT = `당신은 AI 관상 분석 전문가입니다. 사용자가 업로드한 이미지를 실제로 확인하고 아래 규칙을 반드시 따르세요.

[1단계 - 사진 검증 (가장 중요)]
- 이미지에 사람의 얼굴이 명확하게 나와 있는지 먼저 확인하세요.
- 얼굴 사진이 아니거나(예: 손바닥, 사물, 풍경, 동물, 음식, 텍스트/스크린샷, 만화/캐릭터 등),
  얼굴이 너무 작거나 심하게 가려져서 이마/눈/코/입/턱 특징을 확인할 수 없는 경우
  반드시 "valid"를 false로 설정하고 "invalidReason"에 구체적인 이유를 한국어로 작성하세요.
- 절대로 얼굴이 아닌 사진에 대해 관상 분석 내용을 만들어내지 마세요. 확실하지 않으면 false로 처리하세요.

[2단계 - 실제 사진 기반 분석 (valid가 true인 경우만)]
- 사진에서 실제로 관찰되는 특징(이마/눈/코/입/턱)을 근거로 서술하세요. 추측하지 말고 실제로 보이는 내용만 설명하세요.
- 외모를 비하하거나 부정적으로 평가하는 표현은 절대 금지합니다. 항상 따뜻하고 긍정적인 어투를 사용하세요.
- 전통 관상학의 일반적인 해석을 참고용으로 곁들이되, 실제 성격/운명/능력을 사실처럼 단정하지 마세요.
- 사용자의 생년월일/성별 정보가 주어지면 재물/애정/직업/건강 해석에 자연스럽게 참고하세요.

[출력 형식 - 반드시 아래 JSON 객체만 응답하세요. 다른 설명, 인사말, 마크다운 코드펜스를 절대 포함하지 마세요]
{
  "valid": boolean,
  "invalidReason": string 또는 null,
  "features": { "이마": string, "눈": string, "코": string, "입": string, "턱": string },
  "topicResults": { "재물": string, "애정": string, "직업": string, "건강": string, "종합": string }
}

- valid가 false이면 features와 topicResults는 빈 객체 {}로 두세요.
- valid가 true이면 features/topicResults의 모든 항목을 2~4문장으로 구체적으로 작성하세요.
- "종합"은 위 모든 분석을 아우르는 3~5문장의 총평으로 작성하세요.`;

function buildDataUrl(image: string): string {
  if (image.startsWith("data:")) return image;
  return `data:image/jpeg;base64,${image}`;
}

interface FaceVisionResponse {
  valid: boolean;
  invalidReason?: string | null;
  features?: Record<string, string>;
  topicResults?: Record<string, string>;
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; image?: string };
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

  const image = body.image;
  if (!image || typeof image !== "string" || image.length < 100) {
    return NextResponse.json(
      { success: false, error: "얼굴 사진을 첨부해주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // ── [STEP8 - 프리패스 카테고리별 이용횟수 검증] ──
  // Vision API 호출(고비용) 이전에 먼저 검증해, 이미 한도를 초과한 요청은
  // 불필요한 LLM 호출/사진 전송 없이 즉시 차단한다.
  const usageCheck = await checkCategoryUsage(userId, "face");
  if (!usageCheck.allowed) {
    return NextResponse.json(
      {
        success: false,
        error:
          usageCheck.reason === "CATEGORY_LIMIT_REACHED"
            ? `오늘 이 프리패스로 이용할 수 있는 횟수(${usageCheck.maxUsage}회)를 모두 사용했습니다.`
            : "유효한 프리패스가 없습니다. 광고 시청, 파트너 방문 또는 구독으로 프리패스를 받아보세요.",
        reason: usageCheck.reason,
        usageCount: usageCheck.usageCount,
        maxUsage: usageCheck.maxUsage,
      },
      { status: 403, headers: CORS_HEADERS }
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new Error("USER_NOT_FOUND");
    const birthDate = user.profile?.birthDate ?? null;
    const gender = user.gender ?? null;

    // fortune_results.prompt_template_id는 NOT NULL이라 face 도메인 활성 템플릿을
    // 참조 용도로만 가져온다(실제 시스템 프롬프트는 SYSTEM_PROMPT를 사용).
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "face", isActive: true },
      select: { id: true, version: true },
    });
    if (!template) throw new Error("NO_TEMPLATE");

    const userPrompt = [
      "이 사진이 사람의 얼굴 사진인지 먼저 확인한 뒤, 맞다면 관상을 분석해주세요.",
      `참고 - 사용자 생년월일: ${birthDate ?? "미상"}`,
      `참고 - 성별: ${gender ?? "미상"}`,
    ].join("\n");

    const vision = await completeVisionJson<FaceVisionResponse>({
      systemPrompt: SYSTEM_PROMPT,
      userPrompt,
      imageDataUrl: buildDataUrl(image),
      timeoutMs: 40_000,
    });

    // [사진 검증 실패] 얼굴이 아닌 사진 -> 기록 남기지 않고 즉시 에러 응답
    if (!vision.valid) {
      return NextResponse.json(
        {
          success: false,
          error: vision.invalidReason || "얼굴이 잘 보이는 사진으로 다시 촬영해주세요.",
        },
        { status: 422, headers: CORS_HEADERS }
      );
    }

    const features: Record<string, string> = {
      이마: vision.features?.["이마"] || FEATURE_FALLBACK["이마"],
      눈: vision.features?.["눈"] || FEATURE_FALLBACK["눈"],
      코: vision.features?.["코"] || FEATURE_FALLBACK["코"],
      입: vision.features?.["입"] || FEATURE_FALLBACK["입"],
      턱: vision.features?.["턱"] || FEATURE_FALLBACK["턱"],
    };
    const topicResults: Record<string, string> = {
      재물: vision.topicResults?.["재물"] || TOPIC_FALLBACK["재물"],
      애정: vision.topicResults?.["애정"] || TOPIC_FALLBACK["애정"],
      직업: vision.topicResults?.["직업"] || TOPIC_FALLBACK["직업"],
      건강: vision.topicResults?.["건강"] || TOPIC_FALLBACK["건강"],
      종합: vision.topicResults?.["종합"] || TOPIC_FALLBACK["종합"],
    };
    const summary = topicResults["종합"];

    const outcome = await prisma.$transaction(async (tx) => {
      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "face",
          inputPayload: JSON.stringify({ birthDate, gender, hasImage: true }),
          sourceType: "ai_generated",
          pointSpent: 0,
          status: "success",
        },
      });

      const fortuneResult = await tx.fortuneResult.create({
        data: {
          requestId: fortuneRequest.id,
          resultText: summary,
          resultMeta: JSON.stringify({ features, topicResults, summary }),
          aiModel: "claude-haiku-4-5-vision",
          promptTemplateId: template.id,
          promptVersion: template.version,
          status: "active",
        },
      });

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, fortuneResult };
    });

    // ── [STEP8] 실제 분석 성공 후에만 카테고리 이용횟수 +1 ──
    // (valid=false로 위에서 이미 return한 경우는 이 지점에 도달하지 않으므로,
    // 사진 검증에 실패한 시도는 이용횟수를 소모하지 않는다.)
    if (usageCheck.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, "face");
    }

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
    if (message === "NO_TEMPLATE") {
      return NextResponse.json(
        { success: false, error: "관상 분석 설정이 준비되지 않았습니다. 관리자에게 문의해주세요." },
        { status: 503, headers: CORS_HEADERS }
      );
    }
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/fortune/face] LLM 비전 오류:", e.message);
      return NextResponse.json(
        { success: false, error: "관상 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요." },
        { status: 502, headers: CORS_HEADERS }
      );
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
