// 공개(비인증) "사주 운세" 생성 API — Flutter SajuRepository.requestSaju() 대응.
//
// [Phase6 - AI운세 실LLM 연동, 1차: 사주/타로 텍스트 전용] 지금까지 Flutter는
// 완전히 로컬 Mock(시드 기반 하드코딩 텍스트풀)으로만 사주 결과를 생성했다.
// 이 라우트를 신설하여 ai_prompt_templates(도메인: saju/saju_wealth/saju_career/
// saju_love/saju_health)에 등록된 실제 프롬프트를 LLM(GSK_TOKEN 기반 Proxy)에
// 전달해 진짜 AI 생성 텍스트를 받아온다.
//
// [범위 결정] 사주 명식(십간십이지 4주)과 오행 점수는 실제 역학 계산이 아니라
// 여전히 결정론적 규칙(생년월일 해시) 기반으로 생성한다(Mock 시절과 동일).
// 이번 연동의 핵심은 "주제별 해석 텍스트"를 rule-based 텍스트풀 대신 실제
// LLM 응답으로 교체하는 것이다(사용자에게 이미 안내한 1차 범위와 일치).
//
// [트랜잭션 설계] LLM 호출은 네트워크 왕복이 필요해 DB 트랜잭션 밖에서 먼저
// 수행하고, 이후 짧은 DB 트랜잭션에서 fortune_requests/results 기록을 처리한다.
//
// [무료 광고형 구조 재정비 §신규발견] 사주 운세 열람은 복주머니(포인트)를 소비하지
// 않는다. 과거 point_policies(ai_saju_request) 기반 차감→즉시환급 로직은 "복주머니는
// 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시 구조였다.
// 프리패스 상태와도 무관하게 항상 무료로 열람 가능하다.
//
// [saju-output-spec.pdf 대응 — AI 사주 해석 품질 개선, 2026-09-24 설계서 반영]
// 기존에는 ai_prompt_templates.templateBody(자유 서술 프롬프트) → LLM이 400~500자
// 자유 텍스트를 생성 → 그대로 topicResults[topic]에 저장하는 구조였다. 이 구조는
// PDF가 지적한 "반복·짧음·무서움·안 읽힘" 4대 증상의 직접 원인이었다(계산과 표현이
// 분리되지 않고, 출력 형식이 고정되지 않아 LLM이 매번 다른 형태·다른 근거로 답함).
//
// 이번 개선으로 파이프라인을 3단계로 분리한다(PDF §1 원칙 1):
//   ① 계산 엔진(computeChart, 기존 그대로 — 결정론적 해시 기반 pillars/fiveElements)
//   ② 판정 레이어(buildSajuJudgment, 신규 — pillars를 실제 오행 상생상극 규칙으로
//      해석해 day_master/ten_gods_count/elements_ratio/verdict/flow JSON 생성)
//   ③ 표현 레이어(LLM, ai_prompt_templates에 §7 시스템 프롬프트로 교체) — 판정
//      JSON만 받아서 정해진 7블록(headline/nature/strength/caution/flow/actions/
//      closing) JSON으로만 답하도록 강제.
// LLM 응답은 saju-qa-check.ts(§8 자동 검증 스크립트 이식)로 저장 전 검증하고,
// 실패 시 1회 재생성 → 그래도 실패하면 안전 문구로 폴백한다(§11 6번).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";
import { checkCategoryUsage, checkDailyAbsoluteLimit, consumeCategoryUsage } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
import { buildSajuJudgment, type SajuJudgment } from "@/lib/saju-judgment";
import { checkSajuResult, type SajuLlmResult } from "@/lib/saju-qa-check";
import { parseSajuLlmJson, renderSajuLlmResult } from "@/lib/saju-render";
import {
  beginResultAccess,
  completeResultAccess,
  failAndRefundResultAccess,
  ResultAccessError,
  type ResultAccessPaymentMethod,
} from "@/lib/result-access-service";

// [어뷰징 방지 개편 §신규 ②] saju는 uniqueTopics 각각에 대해 LLM을 병렬 호출하므로
// (Promise.allSettled), 클라이언트가 몇 개를 보내든 서버가 최종 방어선으로 최대
// 개수를 강제한다. Flutter saju_input_screen.dart도 동일 상수(3개)로 제한하지만,
// 클라이언트 검증을 우회한 직접 호출에도 서버가 동일하게 방어해야 한다(§8 원칙).
const MAX_TOPICS_PER_REQUEST = 3;

// [saju-output-spec.pdf §8 "운영 파라미터 권장값"] 실패 시 재생성 최대 2회
// (= 최초 시도 1회 + 재시도 1회. PDF 표현: "재생성 횟수 최대 2회").
const MAX_LLM_ATTEMPTS = 2;

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const STEMS = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"];
const BRANCHES = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"];

const TOPIC_DOMAIN: Record<string, string> = {
  종합: "saju",
  재물: "saju_wealth",
  애정: "saju_love",
  직업: "saju_career",
  건강: "saju_health",
  // [운세 카테고리 확장] 사주 월별 운세(saju_monthly) — 기존 다중 토픽 선택 방식을
  // 그대로 재사용해 신규 도메인만 추가 연결한다(입력화면/결과화면 변경 없음).
  월별: "saju_monthly",
};

const FALLBACK_TEXT_BY_TOPIC: Record<string, string> = {
  종합: "전반적으로 안정과 성장이 조화를 이루는 시기입니다. 스스로의 페이스를 지키며 꾸준히 나아간다면 좋은 결실을 맺을 수 있습니다.",
  재물: "안정적인 재물운이 이어지는 흐름입니다. 무리한 투자보다는 계획적인 소비와 저축이 유리합니다.",
  애정: "인간관계에서 따뜻한 기운이 감돌고 있습니다. 서로에 대한 신뢰를 쌓아가는 시기입니다.",
  직업: "주변의 인정을 받으며 성장할 수 있는 흐름입니다. 신중하게 기회를 살펴보세요.",
  건강: "전반적으로 무난하나 과로에 주의가 필요합니다. 규칙적인 생활 패턴을 유지하세요.",
  월별: "이번 달은 준비와 정리가 함께 필요한 시기입니다. 초반에는 신중하게 상황을 살피고, 중반 이후 서서히 기회가 열리니 무리한 결정은 뒤로 미루는 것이 좋습니다.",
};

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

function computeChart(birthDate: string, hasBirthTime: boolean) {
  const seed = hashSeed(birthDate);
  const pillar = (offset: number) =>
    `${STEMS[(seed + offset) % 10]}${BRANCHES[(seed + offset * 3) % 12]}`;

  const pillars = {
    year: pillar(1),
    month: pillar(2),
    day: pillar(3),
    hour: hasBirthTime ? pillar(4) : null,
  };
  const fiveElements = {
    목: 10 + (seed % 20),
    화: 10 + ((seed >> 1) % 20),
    토: 10 + ((seed >> 2) % 20),
    금: 10 + ((seed >> 3) % 20),
    수: 10 + ((seed >> 4) % 20),
  };
  return { pillars, fiveElements, seed };
}

/** [saju-output-spec.pdf §7] 판정 JSON을 사용자 프롬프트에 "재료 목록"으로 담아 전달. */
function buildUserPrompt(params: {
  name: string;
  birthDate: string;
  isLunar: boolean;
  birthTime: string | null;
  topic: string;
  judgment: SajuJudgment;
}): string {
  const { name, birthDate, isLunar, birthTime, topic, judgment } = params;
  return [
    `사용자 정보: ${name}, 생년월일 ${birthDate}(${isLunar ? "음력" : "양력"})`,
    birthTime ? `태어난 시간: ${birthTime}` : "태어난 시간: 미상",
    `요청 주제: ${topic}`,
    "",
    "[계산값] 아래 JSON에 이미 계산·확정된 값만 사용하세요. 절대로 사주를 다시 계산하거나",
    "JSON에 없는 간지·수치·사실을 새로 만들지 마세요:",
    JSON.stringify(judgment),
    "",
    "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서, 반드시 이 계산값만을 근거로",
    "이 사람의 운세를 JSON으로 작성해주세요.",
  ].join("\n");
}

/** LLM 호출 → JSON 파싱 → QA 검증까지 한 번에 수행. 실패 시 null 반환(호출부가 재시도/폴백 처리). */
async function tryGenerateSajuSection(
  systemPrompt: string,
  userPrompt: string
): Promise<{ result: SajuLlmResult; rendered: string } | null> {
  // [saju-output-spec.pdf §11-4] "temperature 0.7" — §8 운영 파라미터 권장값
  // (0.6~0.8, "낮으면 문장이 복붙처럼 반복됨")과도 일치.
  const raw = await completeText({ systemPrompt, userPrompt, maxTokens: 1500, temperature: 0.7 });
  const parsed = parseSajuLlmJson(raw);
  if (!parsed) {
    console.error("[POST /api/public/fortune/saju] LLM JSON 파싱 실패:", raw.slice(0, 200));
    return null;
  }
  const problems = checkSajuResult(parsed);
  if (problems.length > 0) {
    console.error("[POST /api/public/fortune/saju] QA 검증 실패:", problems);
    return null;
  }
  return { result: parsed, rendered: renderSajuLlmResult(parsed) };
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    name?: string;
    birthDate?: string;
    birthTime?: string;
    isLunar?: boolean;
    topics?: string[];
    profileId?: string;
    profileName?: string;
    // [결과보기 통합 권한 시스템 v1.0, Phase2] 신규 필드 — 둘 다 전달되면
    // ResultAccessService(§8) 경로로 처리하고, 전달되지 않으면(기존 Flutter 앱)
    // 아래 레거시 카테고리 이용횟수 검증 경로를 그대로 유지한다(하위호환).
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
  // [사주정보 이름 필드 보완] Flutter 입력 화면이 이전 버전을 호출해도 무효가 되지
  // 않도록, 버전 목록이 비어있으면 '게스트'로 폴백한다.
  const name = body.name && body.name.trim().length > 0 ? body.name.trim() : "게스트";
  const birthDate = body.birthDate;
  const birthTime = body.birthTime ?? null;
  const isLunar = Boolean(body.isLunar);
  const requestedTopics = body.topics && body.topics.length > 0 ? body.topics : ["종합"];
  // [어뷰징 방지 개편 §신규 ②] 클라이언트가 몇 개를 보내든 앞에서부터 최대
  // MAX_TOPICS_PER_REQUEST(3)개까지만 처리한다(1회 호출당 LLM 병렬 호출 수 제한).
  const topics = requestedTopics.slice(0, MAX_TOPICS_PER_REQUEST);
  const profileId = body.profileId ?? null;
  const profileName = body.profileName ?? null;
  // [genderInput] verdict 텍스트에 성별을 노출하지 않지만 saju_json.birth.gender에는
  // 필요 — 클라이언트가 별도 필드로 보내지 않아 기본값 "U"(unspecified)로 둔다.
  const gender = "U";

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!birthDate || typeof birthDate !== "string") {
    return NextResponse.json(
      { success: false, error: "birthDate가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // ── [어뷰징 방지 개편 §신규 ①] 유저별 절대 일일 AI 호출 상한(5회) 검사 ──
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

  // ══════════════════════════════════════════════════════════════
  // [결과보기 통합 권한 시스템 v1.0, Phase2 — ResultAccessService 통합]
  //
  // Flutter가 신규 계약(paymentMethod + transactionId)으로 호출하면 §8 공통
  // 서비스(FREEPASS/POUCH/AD 3택, 서버 원자적 차감, 멱등키, 실패 시 환불)를
  // 그대로 태운다. 두 필드 중 하나라도 없으면(기존 Flutter 앱의 구버전 호출)
  // 레거시 "카테고리 이용횟수 검증"(checkCategoryUsage) 경로를 그대로 유지한다
  // — §9.2 "기존 정상 기능을 불필요하게 재작성하지 않는다" 원칙에 따라 구버전
  // 클라이언트를 깨지 않기 위한 과도기적 분기다. Phase4에서 Flutter가 신규
  // 계약으로 완전히 전환되면 레거시 분기를 정리한다.
  // ══════════════════════════════════════════════════════════════
  const resultAccessTransactionId = body.transactionId?.trim() || null;
  const resultAccessPaymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;
  const useResultAccessService = Boolean(resultAccessTransactionId && resultAccessPaymentMethod);

  // ── [레거시 경로] 프리패스 카테고리별 이용횟수 검증(§8 통합 이전 방식) ──
  // 사주는 fortune_categories.requires_pass=true(프리패스 필수 카테고리)이므로,
  // 클라이언트 진입 게이트(navigateWithPassGate/CategoryGate)를 우회한 직접 호출도
  // 서버에서 동일하게 차단해야 한다. 실제 usageCount 증가는 아래 트랜잭션 성공 후에만 한다.
  let usageCheck: Awaited<ReturnType<typeof checkCategoryUsage>> | null = null;
  if (!useResultAccessService) {
    usageCheck = await checkCategoryUsage(userId, "saju");
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
  }

  // ── [신규 경로] §8.5 "결제 확정 후 AI 생성" — AI 호출 전에 먼저 차감을 확정한다. ──
  let resultAccessBegin: Awaited<ReturnType<typeof beginResultAccess>> | null = null;
  if (useResultAccessService) {
    try {
      resultAccessBegin = await beginResultAccess({
        userId,
        transactionId: resultAccessTransactionId!,
        contentType: "saju",
        categoryKey: "saju",
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
      console.error("[POST /api/public/fortune/saju] ResultAccess 확정 실패:", e);
      return NextResponse.json(
        { success: false, error: "결과보기 권한 확인 중 오류가 발생했습니다." },
        { status: 500, headers: CORS_HEADERS }
      );
    }
  }

  try {
    // 1) 명식/오행은 여전히 결정론적 규칙으로 계산(범위 밖)
    const { pillars, fiveElements, seed } = computeChart(birthDate, !!birthTime);

    // 1.5) [신규] 판정 레이어 — pillars를 실제 오행 상생상극 규칙으로 해석해
    //      day_master/ten_gods_count/elements_ratio/verdict/flow JSON 생성.
    //      모든 topic이 동일한 judgment를 공유한다(사람은 한 명, 판정도 하나).
    const judgment = buildSajuJudgment({
      birthDate,
      birthTime,
      gender,
      isLunar,
      pillars,
      seed,
    });

    // 2) 주제별 활성 프롬프트 템플릿을 조회하고 LLM을 호출
    //    [성능 개선 - 병렬화] saju는 주제마다 서로 다른 도메인(saju/saju_wealth/...)의
    //    템플릿을 조회해야 하므로, 먼저 템플릿을 모두 병렬로 조회한 뒤(1단계),
    //    템플릿이 있는 주제에 대해서만 completeText() 호출을 동시에 발사한다(2단계).
    //    face/palm/compatibility와 동일하게, 순차 호출 시 주제 개수만큼(최대 5개,
    //    최악 150s) 응답시간이 늘어나는 문제를 "가장 느린 1건의 시간"으로 단축한다.
    const uniqueTopics = Array.from(new Set(topics));

    const templateEntries = await Promise.all(
      uniqueTopics.map(async (topic) => {
        const domain = TOPIC_DOMAIN[topic] ?? "saju";
        const template = await prisma.aiPromptTemplate.findFirst({
          where: { fortuneTypeOrDomain: domain, isActive: true },
          select: { id: true, version: true, templateBody: true },
        });
        return { topic, template };
      })
    );

    let primaryTemplate: { id: number; version: number } | null = null;
    for (const { topic, template } of templateEntries) {
      if (template && (!primaryTemplate || topic === "종합")) {
        primaryTemplate = { id: template.id, version: template.version };
      }
    }

    const topicResults: Record<string, string> = {};
    // [saju-output-spec.pdf §3-1] 구조화 JSON 원본도 함께 보관해 두어(추후 Flutter가
    // 블록 단위 렌더링으로 전환할 때 재생성 없이 바로 사용 가능하도록).
    const topicStructured: Record<string, SajuLlmResult> = {};
    for (const { topic, template } of templateEntries) {
      if (!template) {
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
      }
    }

    const withTemplate = templateEntries.filter(
      (e): e is { topic: string; template: NonNullable<(typeof templateEntries)[number]["template"]> } =>
        e.template !== null
    );

    const settled = await Promise.allSettled(
      withTemplate.map(async ({ topic, template }) => {
        const userPrompt = buildUserPrompt({ name, birthDate, isLunar, birthTime, topic, judgment });

        // [saju-output-spec.pdf §11-6 "QA 연결"] 실패 시 1회 재생성 → 그래도
        // 실패하면 안전 문구로 폴백(호출부의 allSettled 실패 처리가 담당).
        let lastError: unknown = null;
        for (let attempt = 1; attempt <= MAX_LLM_ATTEMPTS; attempt++) {
          try {
            const generated = await tryGenerateSajuSection(template.templateBody, userPrompt);
            if (generated) {
              return { topic, ...generated };
            }
            lastError = new Error("QA_OR_PARSE_FAILED");
          } catch (e) {
            lastError = e;
          }
        }
        throw lastError ?? new Error("UNKNOWN_LLM_FAILURE");
      })
    );
    settled.forEach((outcome, index) => {
      const topic = withTemplate[index].topic;
      if (outcome.status === "fulfilled") {
        topicResults[topic] = outcome.value.rendered;
        topicStructured[topic] = outcome.value.result;
      } else {
        console.error(`[POST /api/public/fortune/saju] LLM 생성 실패(topic=${topic}):`, outcome.reason);
        topicResults[topic] = FALLBACK_TEXT_BY_TOPIC[topic] ?? FALLBACK_TEXT_BY_TOPIC["종합"];
      }
    });

    const summary = topicResults["종합"] ?? Object.values(topicResults)[0] ?? "";

    // 3) 짧은 DB 트랜잭션: fortune_requests/results 기록(포인트 차감 없음)
    const outcome = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      // [무료 광고형 구조 재정비 §신규발견] 사주 운세는 완전 무료 — 차감/환급 없음.
      const balance = wallet.balance;
      const cost = 0;
      const refundAmount = 0;

      const fortuneRequest = await tx.fortuneRequest.create({
        data: {
          userId,
          fortuneType: "saju",
          inputPayload: JSON.stringify({ name, birthDate, birthTime, isLunar, topics: uniqueTopics, profileId, profileName }),
          sourceType: "ai_generated",
          pointSpent: cost,
          status: "success",
        },
      });

      let fortuneResult = null;
      if (primaryTemplate) {
        fortuneResult = await tx.fortuneResult.create({
          data: {
            requestId: fortuneRequest.id,
            resultText: summary,
            resultMeta: JSON.stringify({ pillars, fiveElements, judgment, topicResults, topicStructured }),
            aiModel: "claude-haiku-4-5",
            promptTemplateId: primaryTemplate.id,
            promptVersion: primaryTemplate.version,
            status: "active",
          },
        });
      }

      return { requestId: fortuneRequest.id, createdAt: fortuneRequest.createdAt, balance, refundAmount, cost, fortuneResult };
    });

    // ── [레거시] 실제 분석 성공 후에만 카테고리 이용횟수 +1 ──
    if (!useResultAccessService && usageCheck?.userPassId != null) {
      await consumeCategoryUsage(usageCheck.userPassId, userId, "saju");
    }

    // ── [신규] §8.5 마지막 단계: AI 생성 성공 → 거래 최종 확정(status: pending→success) ──
    if (useResultAccessService && resultAccessBegin) {
      await completeResultAccess(resultAccessBegin.transactionId, outcome.requestId);
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `saju_${outcome.requestId}`,
          name,
          pillars,
          fiveElements,
          topicResults,
          // [saju-output-spec.pdf 대응] 구조화 7블록 원본 — 현재 Flutter는 참조하지
          // 않지만(하위호환을 위해 topicResults 텍스트를 그대로 사용), 추후 블록
          // 단위 렌더링으로 전환할 때 이 필드를 바로 사용할 수 있다.
          topicStructured,
          summary,
          createdAt: outcome.createdAt.toISOString(),
          profileId,
          profileName,
          balance: outcome.balance,
          refundAmount: outcome.refundAmount,
          pointSpent: outcome.cost,
          // [결과보기 통합 권한 시스템 v1.0] 신규 경로로 처리된 경우에만 채워진다.
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
    // [결과보기 통합 권한 시스템 v1.0 §8.6] AI 생성 단계에서 실패하면 §8 신규 경로로
    // 이미 차감된 프리패스/복주머니를 transaction_id 기준으로 정확히 복구한다.
    if (useResultAccessService && resultAccessBegin) {
      try {
        await failAndRefundResultAccess(resultAccessBegin.transactionId);
      } catch (refundError) {
        console.error("[POST /api/public/fortune/saju] 환불 처리 실패:", refundError);
      }
    }

    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WALLET_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "지갑을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (e instanceof LlmClientError) {
      console.error("[POST /api/public/fortune/saju] LLM 오류:", e.message);
    }
    console.error("[POST /api/public/fortune/saju] 실패:", e);
    return NextResponse.json(
      { success: false, error: "사주 분석 중 오류가 발생했습니다." },
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
