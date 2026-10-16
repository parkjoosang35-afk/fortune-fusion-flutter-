// 공개(비인증) "AI 관상" 분석 API — 전문 분석 체계 적용 버전.
//
// [버그 수정 배경 — 유지] 기존 구현은 completeText()(텍스트 전용 LLM)만 사용해 실제
// 업로드된 얼굴 사진을 전혀 서버로 전송/분석하지 않고, 로그인 사용자의
// 생년월일/성별 텍스트와 결정론적 시드로 고른 하드코딩 문구만 반환했다.
// Vision 모델 연동(completeVisionJson)으로 이 문제는 이미 해결되어 있었다.
//
// [관상·손금 후속 개발 — 전수 검수 보고서 기준, 3단계 파이프라인 적용]
// saju/route.ts(buildSajuJudgment)와 동일한 "계산과 표현을 분리한다" 원칙을
// 적용한다. 기존에는 Vision LLM 한 번의 호출이 "관찰 + 해석 + 서술"을 전부
// 동시에 수행해, 어떤 문장이 실제 사진 관찰에 근거했는지 전통 관상학 규칙에
// 근거했는지 LLM의 임의 서술인지 구분할 수 없었다. 이제 3단계로 분리한다:
//
//   ① 관찰 레이어(Vision LLM, completeVisionJsonWithUsage) — 사진을 보고
//      오관(눈썹/눈/코/입/귀)·삼정(상정/중정/하정)·십이궁 9궁의 "선택지
//      강제" 질문에만 답한다(해석 금지, 관찰만). 응답 스키마는 FaceObserved.
//   ② 판정 레이어(face-judgment.ts, buildFaceJudgment) — FaceObserved만
//      입력받아 순수 함수로 오관 등급/삼정 균형/4대 주제 verdict를 결정론적
//      으로 산출한다. LLM을 호출하지 않으며, 동일 입력에는 항상 동일 출력.
//   ③ 표현 레이어(LLM, completeTextWithUsage) — 판정 JSON + 관찰 JSON을
//      받아 사람이 읽는 문장으로만 바꾼다. 여기서만 AiPromptTemplate.
//      templateBody(관리자가 수정 가능)를 시스템 프롬프트 톤 가이드로
//      실제 사용한다(기존에는 select:{id,version}으로 조회만 하고 버렸음).
//
// [비용/사용량 로그] ①②③ 중 LLM을 호출하는 ①③ 단계마다 AiRequestLog를
// 기록한다(amulets/compatibility와 동일 패턴). 기존에는 관상/손금 전체가
// 이 테이블을 전혀 사용하지 않았다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  completeVisionJsonWithUsage,
  completeTextWithUsage,
  LlmClientError,
} from "@/lib/llm-client";
import { checkCategoryUsage, checkDailyAbsoluteLimit, consumeCategoryUsage } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
import { buildFaceJudgment, type FaceObserved, type FaceJudgment } from "@/lib/face-judgment";
import { checkFacePalmText } from "@/lib/face-palm-qa-check";
import {
  beginResultAccess,
  completeResultAccess,
  failAndRefundResultAccess,
  ResultAccessError,
  type ResultAccessPaymentMethod,
} from "@/lib/result-access-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// [재시도 원칙 — saju와 동일] 표현 레이어 LLM 응답이 QA 기준에 걸리면 1회 재생성.
const MAX_EXPRESSION_ATTEMPTS = 2;

const TOPIC_FALLBACK: Record<string, string> = {
  재물: "코와 이마의 조화가 좋아 안정적인 재물운을 타고났습니다. 꾸준한 노력이 결실로 이어질 것입니다.",
  애정: "눈매와 입매에서 따뜻한 기운이 느껴지며, 주변 사람들과 좋은 관계를 맺는 데 유리한 인상입니다.",
  직업: "전체적으로 균형잡힌 인상으로, 리더십과 신뢰를 동시에 얻을 수 있는 관상입니다.",
  건강: "혈색과 윤곽이 안정적이라 전반적인 건강 기운이 양호한 편입니다. 다만 무리한 스케줄은 주의하세요.",
  종합: "전체적으로 조화롭고 안정적인 인상으로, 스스로의 강점을 잘 살리면 좋은 흐름을 이어갈 수 있습니다.",
};

const FEATURE_FALLBACK: Record<string, string> = {
  눈썹: "눈썹의 결이 또렷한 인상입니다.",
  눈: "눈매에서 또렷한 기운이 느껴집니다.",
  코: "코의 균형이 안정적인 인상입니다.",
  입: "입매가 단정한 인상입니다.",
  귀: "귀의 윤곽이 또렷한 인상입니다.",
};

// ── ① 관찰 레이어: 선택지 강제 프롬프트(해석 금지, 관찰만) ──
const OBSERVATION_SYSTEM_PROMPT = `당신은 사진 속 얼굴의 생김새를 객관적으로 관찰해 분류하는 역할만 수행합니다.
절대로 성격/운명/길흉을 해석하지 마세요 — 오직 "무엇이 보이는가"만 미리 정해진 선택지 중에서 고르세요.

[1단계 - 사진 검증 (가장 중요)]
- 이미지에 사람의 얼굴이 명확하게 나와 있는지 먼저 확인하세요.
- 얼굴 사진이 아니거나(예: 손바닥, 사물, 풍경, 동물, 음식, 텍스트/스크린샷, 만화/캐릭터 등),
  얼굴이 너무 작거나 심하게 가려져서 아래 항목들을 확인할 수 없는 경우
  반드시 "valid"를 false로 설정하고 "invalidReason"에 구체적인 이유를 한국어로 작성하세요.
- 절대로 얼굴이 아닌 사진에 대해 관찰 내용을 만들어내지 마세요. 확실하지 않으면 false로 처리하세요.

[2단계 - 객관적 관찰만 (valid가 true인 경우만)]
사진에서 실제로 보이는 모습을 아래 스키마의 선택지 중 하나로만 고르세요. 해석이나 평가 문구는 절대 쓰지 말고, 선택지 값만 채우세요.

[출력 형식 - 반드시 아래 JSON 객체만 응답하세요. 다른 설명, 인사말, 마크다운 코드펜스를 절대 포함하지 마세요]
{
  "valid": boolean,
  "invalidReason": string 또는 null,
  "wuguan": {
    "눈썹": { "thickness": "두꺼움"|"보통"|"얇음", "length": "큼"|"보통"|"작음", "shape": 짧은 한국어 묘사(예: "일자형") },
    "눈": { "size": "큼"|"보통"|"작음", "shape": 짧은 한국어 묘사(예: "둥근형") },
    "코": { "size": "큼"|"보통"|"작음", "bridgeHeight": "넓음"|"보통"|"좁음", "shape": 짧은 한국어 묘사 },
    "입": { "size": "큼"|"보통"|"작음", "lipThickness": "두꺼움"|"보통"|"얇음", "shape": 짧은 한국어 묘사 },
    "귀": { "visible": boolean, "size": "큼"|"보통"|"작음" 또는 null, "shape": 짧은 한국어 묘사 또는 null }
  },
  "samjeong": {
    "상정_비율": "넓음"|"보통"|"좁음",
    "중정_비율": "넓음"|"보통"|"좁음",
    "하정_비율": "넓음"|"보통"|"좁음"
  },
  "sibigung": {
    "명궁_인당": "넓음"|"보통"|"좁음",
    "재백궁_코": "풍만"|"보통"|"빈약",
    "관록궁_이마중앙": "풍만"|"보통"|"빈약",
    "부모궁_이마양측": "풍만"|"보통"|"빈약",
    "처첩궁_눈꼬리": "풍만"|"보통"|"빈약",
    "천이궁_눈썹꼬리위": "풍만"|"보통"|"빈약",
    "노복궁_턱": "풍만"|"보통"|"빈약",
    "형제궁_눈썹": "풍만"|"보통"|"빈약",
    "전택궁_눈꺼풀": "풍만"|"보통"|"빈약"
  }
}
- valid가 false이면 wuguan/samjeong/sibigung은 각 하위 필드를 생략 가능한 형태로 비워두되, 키 자체는 남겨도 됩니다.
- 반드시 제시된 선택지 문자열 중 하나만 정확히 사용하세요(다른 표현 금지).`;

// ── ③ 표현 레이어: 판정 JSON만 근거로 문장을 쓰게 하는 시스템 프롬프트 ──
// 관리자가 ai-content/prompts/face 화면에서 설정한 템플릿(톤/분량 가이드)을
// 앞에 덧붙이고, 그 뒤에 "반드시 이 JSON 근거만 사용" 규칙을 고정 추가한다.
// 템플릿 전문을 통째로 교체하지 않는 이유: 관리자가 자유 서술형(마크다운 긴 글)
// 템플릿을 입력해도 JSON 스키마 강제가 깨지지 않도록 안전장치를 유지하기 위함.
function buildExpressionSystemPrompt(adminTemplateBody: string): string {
  return `${adminTemplateBody}

---
[필수 규칙 — 위 지침과 함께 반드시 지키세요]
- 아래 [판정 근거] JSON에 이미 계산된 오관/삼정/십이궁 판정만 근거로 사용하세요. 새로운 관찰 내용을 지어내지 마세요.
- 외모를 비하하거나 부정적으로 단정하는 표현은 금지합니다. 항상 따뜻하고 긍정적인 어투를 사용하세요.
- 실제 성격/운명/능력을 사실처럼 단정하지 마세요("반드시", "절대", "100%" 등 확정 표현 금지).
- 출력은 반드시 아래 JSON 객체 하나만 작성하세요. 다른 설명, 마크다운 코드펜스를 포함하지 마세요.
{
  "features": { "눈썹": string, "눈": string, "코": string, "입": string, "귀": string },
  "topicResults": { "재물": string, "애정": string, "직업": string, "건강": string, "종합": string }
}
- features/topicResults의 모든 항목을 2~4문장으로 구체적으로 작성하세요.
- "종합"은 위 모든 분석을 아우르는 3~5문장의 총평으로 작성하세요.`;
}

function buildDataUrl(image: string): string {
  if (image.startsWith("data:")) return image;
  return `data:image/jpeg;base64,${image}`;
}

interface ExpressionResponse {
  features?: Record<string, string>;
  topicResults?: Record<string, string>;
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    image?: string;
    paymentMethod?: string;
    transactionId?: string;
    adSessionId?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const image = body.image;
  const resultAccessTransactionId = body.transactionId?.trim() || null;
  const resultAccessPaymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;
  const useResultAccessService = Boolean(resultAccessTransactionId && resultAccessPaymentMethod);
  if (!image || typeof image !== "string" || image.length < 100) {
    return NextResponse.json(
      { success: false, error: "얼굴 사진을 첨부해주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const dailyLimitCheck = await checkDailyAbsoluteLimit(userId);
  if (!dailyLimitCheck.allowed) {
    return NextResponse.json(
      {
        success: false,
        error: `하루 이용 가능한 AI 운세 횟수(${dailyLimitCheck.maxUsage}회)를 모두 사용했습니다. 내일 다시 이용해주세요.`,
        reason: "DAILY_ABSOLUTE_LIMIT_REACHED",
        usageCount: dailyLimitCheck.usageCount,
        maxUsage: dailyLimitCheck.maxUsage,
      },
      { status: 403, headers: CORS_HEADERS }
    );
  }

  const usageCheck = useResultAccessService ? null : await checkCategoryUsage(userId, "face");
  if (usageCheck && !usageCheck.allowed) {
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

  let resultAccessBegin: Awaited<ReturnType<typeof beginResultAccess>> | null = null;
  if (useResultAccessService) {
    try {
      resultAccessBegin = await beginResultAccess({
        userId,
        transactionId: resultAccessTransactionId!,
        contentType: "face",
        categoryKey: "face",
        paymentMethod: resultAccessPaymentMethod!,
        adSessionId: body.adSessionId ?? null,
      });
    } catch (e) {
      if (e instanceof ResultAccessError) {
        const AD_SESSION_STATUS: Record<string, number> = {
          AD_SESSION_REQUIRED: 400,
          AD_SESSION_NOT_FOUND: 404,
          AD_SESSION_NOT_COMPLETED: 409,
          AD_SESSION_ALREADY_USED: 409,
        };
        const status =
          e.code === "NO_FREEPASS_BALANCE"
            ? 403
            : e.code === "INSUFFICIENT_POUCH_BALANCE"
              ? 409
              : AD_SESSION_STATUS[e.code] ?? 400;
        return NextResponse.json(
          { success: false, error: e.message, reason: e.code },
          { status, headers: CORS_HEADERS }
        );
      }
      console.error("[POST /api/public/fortune/face] ResultAccess 확정 실패:", e);
      return NextResponse.json(
        { success: false, error: "결과보기 권한 확인 중 오류가 발생했습니다." },
        { status: 500, headers: CORS_HEADERS }
      );
    }
  }

  // AiRequestLog는 FortuneRequest 생성 전에도 기록할 수 있도록 requestRefId를
  // 나중에 채우는 방식 대신, 단순하게 "성공적으로 생성된 fortuneRequest.id"를
  // 공유 참조로 사용한다(① 관찰 단계 로그는 트랜잭션 밖에서 먼저 기록하고,
  // 생성된 fortuneRequest가 없는 경우 requestRefId=null로 남긴다).
  async function logAiRequest(params: {
    aiModel: string;
    status: "success" | "failed" | "timeout";
    latencyMs: number;
    tokenUsage?: number;
    costEstimate?: number;
    requestRefId?: number | null;
  }) {
    try {
      await prisma.aiRequestLog.create({
        data: {
          domain: "face",
          requestRefId: params.requestRefId ?? null,
          aiModel: params.aiModel,
          latencyMs: params.latencyMs,
          tokenUsage: params.tokenUsage ?? null,
          costEstimate: params.costEstimate ?? null,
          status: params.status,
        },
      });
    } catch (e) {
      // 로그 기록 실패는 본 기능(관상 분석)을 막아서는 안 된다.
      console.error("[POST /api/public/fortune/face] AiRequestLog 기록 실패:", e);
    }
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new Error("USER_NOT_FOUND");
    const birthDate = user.profile?.birthDate ?? null;
    const gender = user.gender ?? null;

    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "face", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });
    if (!template) throw new Error("NO_TEMPLATE");

    // ── ① 관찰 레이어 ──
    const obsStarted = Date.now();
    let observed: FaceObserved;
    try {
      const obsResult = await completeVisionJsonWithUsage<FaceObserved>({
        systemPrompt: OBSERVATION_SYSTEM_PROMPT,
        userPrompt: "이 사진이 사람의 얼굴 사진인지 먼저 확인한 뒤, 맞다면 오관/삼정/십이궁 항목을 선택지 중에서만 골라 관찰 결과를 작성해주세요.",
        imageDataUrl: buildDataUrl(image),
        timeoutMs: 40_000,
      });
      observed = obsResult.data;
      await logAiRequest({
        aiModel: `${obsResult.usage.model}-vision-observe`,
        status: "success",
        latencyMs: Date.now() - obsStarted,
        tokenUsage: obsResult.usage.inputTokens + obsResult.usage.outputTokens,
        costEstimate: obsResult.usage.costEstimateUsd,
      });
    } catch (e) {
      await logAiRequest({
        aiModel: "claude-haiku-4-5-vision-observe",
        status: "failed",
        latencyMs: Date.now() - obsStarted,
      });
      throw e;
    }

    if (!observed.valid) {
      if (useResultAccessService && resultAccessBegin) {
        try {
          await failAndRefundResultAccess(resultAccessBegin.transactionId);
        } catch (refundError) {
          console.error("[POST /api/public/fortune/face] 사진검증실패 환불 실패:", refundError);
        }
      }
      return NextResponse.json(
        {
          success: false,
          error: observed.invalidReason || "얼굴이 잘 보이는 사진으로 다시 촬영해주세요.",
        },
        { status: 422, headers: CORS_HEADERS }
      );
    }

    // ── ② 판정 레이어(순수 함수, LLM 비개입) ──
    const judgment: FaceJudgment = buildFaceJudgment(observed);

    // ── ③ 표현 레이어 ──
    const expressionUserPrompt = [
      `사용자 생년월일: ${birthDate ?? "미상"}`,
      `성별: ${gender ?? "미상"}`,
      "",
      "[판정 근거] 아래 JSON은 사진 관찰 + 전통 관상학 오관/삼정/십이궁 규칙으로 이미 계산된 결과입니다. 새로 관찰하지 말고 이 근거만 사용해 문장을 작성하세요:",
      JSON.stringify({ observed: { wuguan: observed.wuguan, samjeong: observed.samjeong, sibigung: observed.sibigung }, judgment }),
    ].join("\n");

    let expression: ExpressionResponse | null = null;
    let expressionUsage: { model: string; inputTokens: number; outputTokens: number; costEstimateUsd: number } | null = null;
    const expStarted = Date.now();
    for (let attempt = 1; attempt <= MAX_EXPRESSION_ATTEMPTS; attempt++) {
      try {
        const { text, usage } = await completeTextWithUsage({
          systemPrompt: buildExpressionSystemPrompt(template.templateBody),
          userPrompt: expressionUserPrompt,
          maxTokens: 1500,
          temperature: 0.7,
        });
        expressionUsage = usage;
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) continue;
        const parsed = JSON.parse(jsonMatch[0]) as ExpressionResponse;
        const allTexts = [
          ...Object.values(parsed.features ?? {}),
          ...Object.values(parsed.topicResults ?? {}),
        ];
        const problems = checkFacePalmText(allTexts);
        if (problems.length > 0) {
          console.error("[POST /api/public/fortune/face] 표현레이어 QA 실패:", problems);
          continue;
        }
        expression = parsed;
        break;
      } catch (e) {
        console.error(`[POST /api/public/fortune/face] 표현레이어 시도 ${attempt} 실패:`, e);
      }
    }
    await logAiRequest({
      aiModel: expressionUsage?.model ? `${expressionUsage.model}-express` : "claude-haiku-4-5-express",
      status: expression ? "success" : "failed",
      latencyMs: Date.now() - expStarted,
      tokenUsage: expressionUsage ? expressionUsage.inputTokens + expressionUsage.outputTokens : undefined,
      costEstimate: expressionUsage?.costEstimateUsd,
    });

    const features: Record<string, string> = {
      눈썹: expression?.features?.["눈썹"] || FEATURE_FALLBACK["눈썹"],
      눈: expression?.features?.["눈"] || FEATURE_FALLBACK["눈"],
      코: expression?.features?.["코"] || FEATURE_FALLBACK["코"],
      입: expression?.features?.["입"] || FEATURE_FALLBACK["입"],
      귀: expression?.features?.["귀"] || FEATURE_FALLBACK["귀"],
    };
    const topicResults: Record<string, string> = {
      재물: expression?.topicResults?.["재물"] || TOPIC_FALLBACK["재물"],
      애정: expression?.topicResults?.["애정"] || TOPIC_FALLBACK["애정"],
      직업: expression?.topicResults?.["직업"] || TOPIC_FALLBACK["직업"],
      건강: expression?.topicResults?.["건강"] || TOPIC_FALLBACK["건강"],
      종합: expression?.topicResults?.["종합"] || TOPIC_FALLBACK["종합"],
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
          // [관찰/판정/표현 구분 보관] 기존 features/topicResults/summary는 그대로
          // 유지하고(Flutter 하위호환), observed/judgment를 추가로 저장해
          // 추후 "사진 관찰 vs 전통 해석 규칙 vs LLM 최종 풀이"를 구분해 볼 수 있게 한다.
          resultMeta: JSON.stringify({ features, topicResults, summary, observed, judgment }),
          aiModel: "claude-haiku-4-5-vision+judgment",
          promptTemplateId: template.id,
          promptVersion: template.version,
          status: "active",
        },
      });

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, fortuneResult };
    });

    if (!useResultAccessService && usageCheck?.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, "face");
    }

    if (useResultAccessService && resultAccessBegin) {
      await completeResultAccess(resultAccessBegin.transactionId, outcome.requestId);
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
          resultAccess: resultAccessBegin
            ? {
                transactionId: resultAccessBegin.transactionId,
                paymentMethod: resultAccessBegin.paymentMethod,
                amount: resultAccessBegin.amount,
                freePassRemaining: resultAccessBegin.freePassRemaining,
                pouchBalance: resultAccessBegin.pouchBalance,
              }
            : null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (useResultAccessService && resultAccessBegin) {
      try {
        await failAndRefundResultAccess(resultAccessBegin.transactionId);
      } catch (refundError) {
        console.error("[POST /api/public/fortune/face] 환불 처리 실패:", refundError);
      }
    }

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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
