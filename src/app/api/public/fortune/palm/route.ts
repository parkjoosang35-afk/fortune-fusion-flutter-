// 공개(비인증) "AI 손금" 분석 API — 전문 분석 체계 적용 버전.
//
// [버그 수정 배경 — 유지] face/route.ts와 동일한 문제. Vision 모델 연동
// (completeVisionJson)으로 실사진 미반영 문제는 이미 해결되어 있었다.
//
// [손금 hand 파라미터 반영] 클라이언트(palm_repository.dart)는 이미
// 'right'|'left' 문자열을 body.hand로 전송 중이었으나, 서버가 이를 전혀
// 읽지 않아 좌/우 구분이 분석에 반영되지 않는 버그가 있었다. 이번 개편에서
// hand를 관찰 프롬프트와 판정 레이어(palm-judgment.ts)에 모두 반영한다.
//
// [관상·손금 후속 개발 — 전수 검수 보고서 기준, 3단계 파이프라인 적용]
// face/route.ts와 동일한 구조:
//   ① 관찰 레이어(Vision LLM) — 사진+hand를 보고 주요 손금(생명선/두뇌선/
//      감정선/운명선)·보조 손금(태양선/수성선/결혼선)의 "선택지 강제" 질문에만
//      답한다(해석 금지, 관찰만). 응답 스키마는 PalmObserved.
//   ② 판정 레이어(palm-judgment.ts, buildPalmJudgment) — PalmObserved(hand
//      포함)만 입력받아 순수 함수로 주요선 등급/4대 주제 verdict를 결정론적
//      으로 산출한다. LLM을 호출하지 않으며, hand가 다르면 hook 문구의
//      해석 관점(선천/후천)이 달라진다(동일 관찰값이라도 hand 반영 확인 가능).
//   ③ 표현 레이어(LLM) — 판정 JSON만 근거로 문장을 쓴다. AiPromptTemplate.
//      templateBody를 시스템 프롬프트 톤 가이드로 실제 사용한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  completeVisionJsonWithUsage,
  completeTextWithUsage,
  LlmClientError,
} from "@/lib/llm-client";
import { checkCategoryUsage, checkDailyAbsoluteLimit, consumeCategoryUsage } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
import { buildPalmJudgment, type PalmObserved, type PalmJudgment, type PalmHand } from "@/lib/palm-judgment";
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

const MAX_EXPRESSION_ATTEMPTS = 2;

const TOPIC_FALLBACK: Record<string, string> = {
  재물: "운명선과 생명선의 조화가 좋아 꾸준한 재물 축적이 가능한 손금입니다.",
  애정: "감정선이 뚜렷하여 진솔한 감정 표현으로 좋은 인연을 만날 가능성이 높습니다.",
  직업: "두뇌선의 흐름이 안정적이라 전문성을 쌓아가는 데 유리한 조건입니다.",
  건강: "생명선이 깊게 새겨져 있어 전반적인 체력과 회복력이 좋은 편입니다.",
  종합: "전체적으로 균형 잡힌 손금으로, 스스로의 강점을 신뢰하고 나아가면 좋은 결실을 맺을 수 있습니다.",
};

const LINE_FALLBACK: Record<string, string> = {
  생명선: "생명선의 흐름이 안정적인 인상입니다.",
  두뇌선: "두뇌선의 흐름이 안정적인 인상입니다.",
  감정선: "감정선의 흐름이 안정적인 인상입니다.",
  운명선: "운명선의 흐름이 안정적인 인상입니다.",
};

type NormalizedHand = PalmHand;
function normalizeHand(value: string | undefined): NormalizedHand {
  return value === "left" ? "left" : "right";
}
function handLabelKo(hand: NormalizedHand): string {
  return hand === "left" ? "왼손" : "오른손";
}

// ── ① 관찰 레이어: 선택지 강제 프롬프트(해석 금지, 관찰만) ──
function buildObservationSystemPrompt(hand: NormalizedHand): string {
  return `당신은 사진 속 손바닥의 손금을 객관적으로 관찰해 분류하는 역할만 수행합니다.
이 사진은 사용자가 촬영 화면에서 "${handLabelKo(hand)}"으로 직접 선택하고 찍은 손입니다.
절대로 운명/길흉을 해석하지 마세요 — 오직 "무엇이 보이는가"만 미리 정해진 선택지 중에서 고르세요.

[1단계 - 사진 검증 (가장 중요)]
- 이미지에 사람의 손바닥(손금이 보이는 손 안쪽 면)이 명확하게 나와 있는지 먼저 확인하세요.
- 손바닥 사진이 아니거나(예: 얼굴, 손등, 사물, 풍경, 동물, 음식, 텍스트/스크린샷, 만화/캐릭터 등),
  손바닥이 너무 작거나 흐릿하거나 가려져서 아래 항목들을 확인할 수 없는 경우
  반드시 "valid"를 false로 설정하고 "invalidReason"에 구체적인 이유를 한국어로 작성하세요.
- 절대로 손바닥이 아닌 사진에 대해 관찰 내용을 만들어내지 마세요. 확실하지 않으면 false로 처리하세요.

[2단계 - 객관적 관찰만 (valid가 true인 경우만)]
사진에서 실제로 보이는 모습을 아래 스키마의 선택지 중 하나로만 고르세요. 해석이나 평가 문구는 절대 쓰지 말고, 선택지 값만 채우세요.

[출력 형식 - 반드시 아래 JSON 객체만 응답하세요. 다른 설명, 인사말, 마크다운 코드펜스를 절대 포함하지 마세요]
{
  "valid": boolean,
  "invalidReason": string 또는 null,
  "majorLines": {
    "생명선": { "length": "긺"|"보통"|"짧음", "depth": "깊음"|"보통"|"옅음", "shape": "직선형"|"곡선형"|"끊어짐"|"갈라짐(지선)" },
    "두뇌선": { "length": "긺"|"보통"|"짧음", "depth": "깊음"|"보통"|"옅음", "shape": "직선형"|"곡선형"|"끊어짐"|"갈라짐(지선)" },
    "감정선": { "length": "긺"|"보통"|"짧음", "depth": "깊음"|"보통"|"옅음", "shape": "직선형"|"곡선형"|"끊어짐"|"갈라짐(지선)" },
    "운명선": { "presence": "뚜렷함"|"흐릿함"|"없음", "shape": "직선형"|"곡선형"|"끊어짐"|"갈라짐(지선)" }
  },
  "minorLines": {
    "태양선": { "presence": "뚜렷함"|"흐릿함"|"없음" },
    "수성선": { "presence": "뚜렷함"|"흐릿함"|"없음" },
    "결혼선": { "presence": "뚜렷함"|"흐릿함"|"없음", "count": "없음"|"1개"|"2개 이상" }
  }
}
- 반드시 제시된 선택지 문자열 중 하나만 정확히 사용하세요(다른 표현 금지).`;
}

// ── ③ 표현 레이어 ──
function buildExpressionSystemPrompt(adminTemplateBody: string): string {
  return `${adminTemplateBody}

---
[필수 규칙 — 위 지침과 함께 반드시 지키세요]
- 아래 [판정 근거] JSON에 이미 계산된 주요 손금/보조 손금 판정만 근거로 사용하세요. 새로운 관찰 내용을 지어내지 마세요.
- "hand_interpretation_note"에 명시된 왼손(선천)/오른손(후천) 해석 관점을 자연스럽게 반영하세요.
- 부정적으로 단정하는 표현은 피하고, 항상 따뜻하고 긍정적인 어투를 사용하세요.
- 실제 운명/건강/능력을 사실처럼 단정하지 마세요("반드시", "절대", "100%" 등 확정 표현 금지).
- 출력은 반드시 아래 JSON 객체 하나만 작성하세요. 다른 설명, 마크다운 코드펜스를 포함하지 마세요.
{
  "lines": { "생명선": string, "두뇌선": string, "감정선": string, "운명선": string },
  "topicResults": { "재물": string, "애정": string, "직업": string, "건강": string, "종합": string }
}
- lines/topicResults의 모든 항목을 2~4문장으로 구체적으로 작성하세요.
- "종합"은 위 모든 분석을 아우르는 3~5문장의 총평으로 작성하세요.`;
}

function buildDataUrl(image: string): string {
  if (image.startsWith("data:")) return image;
  return `data:image/jpeg;base64,${image}`;
}

interface ExpressionResponse {
  lines?: Record<string, string>;
  topicResults?: Record<string, string>;
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    image?: string;
    paymentMethod?: string;
    transactionId?: string;
    adSessionId?: string;
    hand?: string;
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
  const hand = normalizeHand(body.hand);
  const resultAccessTransactionId = body.transactionId?.trim() || null;
  const resultAccessPaymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;
  const useResultAccessService = Boolean(resultAccessTransactionId && resultAccessPaymentMethod);
  if (!image || typeof image !== "string" || image.length < 100) {
    return NextResponse.json(
      { success: false, error: "손바닥 사진을 첨부해주세요." },
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

  const usageCheck = useResultAccessService ? null : await checkCategoryUsage(userId, "palm");
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
        contentType: "palm",
        categoryKey: "palm",
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
      console.error("[POST /api/public/fortune/palm] ResultAccess 확정 실패:", e);
      return NextResponse.json(
        { success: false, error: "결과보기 권한 확인 중 오류가 발생했습니다." },
        { status: 500, headers: CORS_HEADERS }
      );
    }
  }

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
          domain: "palm",
          requestRefId: params.requestRefId ?? null,
          aiModel: params.aiModel,
          latencyMs: params.latencyMs,
          tokenUsage: params.tokenUsage ?? null,
          costEstimate: params.costEstimate ?? null,
          status: params.status,
        },
      });
    } catch (e) {
      console.error("[POST /api/public/fortune/palm] AiRequestLog 기록 실패:", e);
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
      where: { fortuneTypeOrDomain: "palm", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });
    if (!template) throw new Error("NO_TEMPLATE");

    // ── ① 관찰 레이어 ──
    const obsStarted = Date.now();
    let observed: PalmObserved;
    try {
      const obsResult = await completeVisionJsonWithUsage<Omit<PalmObserved, "hand">>({
        systemPrompt: buildObservationSystemPrompt(hand),
        userPrompt: "이 사진이 사람의 손바닥 사진인지 먼저 확인한 뒤, 맞다면 주요 손금과 보조 손금 항목을 선택지 중에서만 골라 관찰 결과를 작성해주세요.",
        imageDataUrl: buildDataUrl(image),
        timeoutMs: 40_000,
      });
      observed = { ...obsResult.data, hand };
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
          console.error("[POST /api/public/fortune/palm] 사진검증실패 환불 실패:", refundError);
        }
      }
      return NextResponse.json(
        {
          success: false,
          error: observed.invalidReason || "손바닥이 잘 보이는 사진으로 다시 촬영해주세요.",
        },
        { status: 422, headers: CORS_HEADERS }
      );
    }

    // ── ② 판정 레이어(순수 함수, LLM 비개입, hand 반영) ──
    const judgment: PalmJudgment = buildPalmJudgment(observed);

    // ── ③ 표현 레이어 ──
    const expressionUserPrompt = [
      `사용자 생년월일: ${birthDate ?? "미상"}`,
      `성별: ${gender ?? "미상"}`,
      `촬영한 손: ${handLabelKo(hand)}`,
      "",
      "[판정 근거] 아래 JSON은 사진 관찰 + 전통 수상학 주요선/보조선 규칙으로 이미 계산된 결과입니다. 새로 관찰하지 말고 이 근거만 사용해 문장을 작성하세요:",
      JSON.stringify({ observed: { majorLines: observed.majorLines, minorLines: observed.minorLines }, judgment }),
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
          ...Object.values(parsed.lines ?? {}),
          ...Object.values(parsed.topicResults ?? {}),
        ];
        const problems = checkFacePalmText(allTexts);
        if (problems.length > 0) {
          console.error("[POST /api/public/fortune/palm] 표현레이어 QA 실패:", problems);
          continue;
        }
        expression = parsed;
        break;
      } catch (e) {
        console.error(`[POST /api/public/fortune/palm] 표현레이어 시도 ${attempt} 실패:`, e);
      }
    }
    await logAiRequest({
      aiModel: expressionUsage?.model ? `${expressionUsage.model}-express` : "claude-haiku-4-5-express",
      status: expression ? "success" : "failed",
      latencyMs: Date.now() - expStarted,
      tokenUsage: expressionUsage ? expressionUsage.inputTokens + expressionUsage.outputTokens : undefined,
      costEstimate: expressionUsage?.costEstimateUsd,
    });

    const lines: Record<string, string> = {
      생명선: expression?.lines?.["생명선"] || LINE_FALLBACK["생명선"],
      두뇌선: expression?.lines?.["두뇌선"] || LINE_FALLBACK["두뇌선"],
      감정선: expression?.lines?.["감정선"] || LINE_FALLBACK["감정선"],
      운명선: expression?.lines?.["운명선"] || LINE_FALLBACK["운명선"],
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
          fortuneType: "palm",
          inputPayload: JSON.stringify({ birthDate, gender, hasImage: true, hand }),
          sourceType: "ai_generated",
          pointSpent: 0,
          status: "success",
        },
      });

      const fortuneResult = await tx.fortuneResult.create({
        data: {
          requestId: fortuneRequest.id,
          resultText: summary,
          resultMeta: JSON.stringify({ lines, topicResults, summary, hand, observed, judgment }),
          aiModel: "claude-haiku-4-5-vision+judgment",
          promptTemplateId: template.id,
          promptVersion: template.version,
          status: "active",
        },
      });

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, fortuneResult };
    });

    if (!useResultAccessService && usageCheck?.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, "palm");
    }

    if (useResultAccessService && resultAccessBegin) {
      await completeResultAccess(resultAccessBegin.transactionId, outcome.requestId);
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `palm_${outcome.requestId}`,
          hand,
          lines,
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
        console.error("[POST /api/public/fortune/palm] 환불 처리 실패:", refundError);
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
        { success: false, error: "손금 분석 설정이 준비되지 않았습니다. 관리자에게 문의해주세요." },
        { status: 503, headers: CORS_HEADERS }
      );
    }
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/fortune/palm] LLM 비전 오류:", e.message);
      return NextResponse.json(
        { success: false, error: "손금 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요." },
        { status: 502, headers: CORS_HEADERS }
      );
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
