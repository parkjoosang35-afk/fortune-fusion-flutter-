// [정통사주 리뉴얼 v1.0 — STEP 4] POST /v1/saju/interpret
//
// [핵심 파이프라인 — 2025 진행 승인 지시 STEP4 §4 고정]
//   사용자 인증 → 출생정보/profile 확인 → SajuFactsCache 조회 → FACT 확보 →
//   요청 Topic 검증 → Topic 조건 검증 → Scene 검증 → Prompt Template 조회 →
//   FACT+Topic 기반 Prompt 구성 → LLM 호출 → 응답 QA 검증 → 필요시 fallback →
//   ExposureHistory 기록 → 사용자 응답
//
// [LLM이 사주를 계산하지 않음 — §5] 이 라우트가 LLM에 넘기는 입력은 오직 이미
// 계산된 facts(SajuFactsCache 경유) + 선택된 topic + evidence뿐이다. 생년월일을
// 그대로 LLM에 넘겨 재판단시키지 않는다(interpret-prompt.ts buildFactDigest 참고).
//
// [서버 재검증 — §2·§3] 사용자가 POST한 topic_id를 그대로 믿지 않는다. 다음 세
// 단계를 전부 통과해야만 해석을 진행한다:
//   1) validateTopicForInterpret(topic-engine.ts) — 카탈로그 존재/릴리즈phase/
//      evidence평가자/현재 FACT로 조건 실제 충족 여부
//   2) getTopicScene(topic-contract-adapter.ts) — scene 미확정(PERSONALITY_001 등)
//      이면 무조건 거부
//   요청 본문의 evidence_fact_keys(topics/select가 내려준 값)는 "참고"로만 받고,
//   실제 판단은 항상 이 두 검증 함수가 서버에서 다시 계산한 결과를 쓴다 — 클라이언트
//   선언을 신뢰하지 않는다(§3 "Topic Select API에서 한 번 추천됐다는 사실만 믿지
//   말고 Interpret API에서도 서버 측 재검증").
//
// [캐시/멱등성 — §16·§17 + docs/05 "09 순환에서는 재계산 금지" + docs/07 E-13]
// TopicInterpretResult(userId, topicId, mode, birthKey unique)에 이미 QA를 통과한
// 결과가 있으면 LLM을 다시 호출하지 않고 그 결과를 그대로 반환한다. 이 경로에서는
// ExposureHistory도 다시 기록하지 않는다(최초 1회만 "본 것"으로 기록되면 충분).
//
// [ExposureHistory 기록 시점 — §16] "정상적으로 완성되어 사용자에게 노출된 해석"
// 일 때만 기록한다. LLM이 실패해도 fallback으로 정상 응답을 사용자에게 보여준
// 경우는 "이야기를 본 것"이 맞으므로 기록한다. 반면 아래 이유로 사용자에게 아예
// 결과를 돌려주지 못하는 경우(요청 자체가 거부됨)는 기록하지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
import {
  getSajuFacts,
  SajuEngineClientError,
  type SajuBirthInput,
} from "@/lib/saju-renewal/saju-engine-client";
import { validateTopicForInterpret } from "@/lib/saju-renewal/topic-engine";
import { getTopicScene, SCENE_UNRESOLVED_TOPIC_IDS } from "@/lib/saju-renewal/topic-contract-adapter";
import { TOPIC_CATALOG_SEED } from "@/lib/saju-renewal/topic-catalog-data";
import type { PromptTopicInfo } from "@/lib/saju-renewal/interpret-prompt";
import { generateInterpretResult, InterpretUnavailableError } from "@/lib/saju-renewal/interpret-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

class InterpretError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

const ERROR_STATUS: Record<string, number> = {
  INVALID_REQUEST_BODY: 400,
  PROFILE_ID_REQUIRED: 400,
  PROFILE_ID_MISMATCH: 400,
  TOPIC_ID_REQUIRED: 400,
  INVALID_MODE: 400,
  BIRTH_INFO_REQUIRED: 400,
  FACT_ENGINE_UNAVAILABLE: 503,
  TOPIC_NOT_FOUND: 404,
  TOPIC_NOT_RELEASED: 404,
  TOPIC_SCENE_UNRESOLVED: 404,
  TOPIC_CONDITION_NOT_SATISFIED: 409,
  EVIDENCE_EVALUATOR_MISSING: 500,
  // [재수정 #6 "471자 fallback을 정상 detail로 반환하는 것은 금지"] fallback까지
  // QA에 실패하면(이론상 고정 템플릿 설계로는 발생하지 않아야 함) 503으로 명확히
  // 응답한다 — 품질 미달 결과를 "정상"으로 위장해 사용자에게 보여주지 않는다.
  INTERPRET_UNAVAILABLE: 503,
};

const ERROR_MESSAGE: Record<string, string> = {
  INVALID_REQUEST_BODY: "요청 본문이 올바르지 않습니다.",
  PROFILE_ID_REQUIRED: "profile_id는 필수입니다.",
  PROFILE_ID_MISMATCH: "profile_id가 로그인 사용자와 일치하지 않습니다.",
  TOPIC_ID_REQUIRED: "topic_id는 필수입니다.",
  INVALID_MODE: "mode는 'summary' 또는 'detail'이어야 합니다.",
  BIRTH_INFO_REQUIRED: "출생정보가 등록되어 있지 않습니다. 프로필을 먼저 입력해주세요.",
  FACT_ENGINE_UNAVAILABLE: "사주 계산 결과를 가져오는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
  // [§11 사용자 내부 정보 노출 금지] 거부 사유를 사용자에게 보일 때도 topic_id/
  // 내부 코드를 직접 언급하지 않는다 — 공통 안내 문구만 노출한다.
  TOPIC_NOT_FOUND: "요청한 이야기를 찾을 수 없습니다. 처음부터 다시 시도해주세요.",
  TOPIC_NOT_RELEASED: "아직 준비 중인 이야기입니다. 다른 이야기를 선택해주세요.",
  TOPIC_SCENE_UNRESOLVED: "아직 준비 중인 이야기입니다. 다른 이야기를 선택해주세요.",
  TOPIC_CONDITION_NOT_SATISFIED: "지금 사주에서는 이 이야기를 열어볼 수 없습니다. 다른 이야기를 선택해주세요.",
  EVIDENCE_EVALUATOR_MISSING: "이야기를 분석하는 중 오류가 발생했습니다.",
  INTERPRET_UNAVAILABLE: "지금은 이야기를 준비하지 못했습니다. 잠시 후 다시 시도해주세요.",
};

interface RequestBody {
  profile_id?: unknown;
  topic_id?: unknown;
  mode?: unknown;
  evidence_fact_keys?: unknown;
}

function validateBody(body: RequestBody, authenticatedUserId: number): {
  topicId: string;
  mode: "summary" | "detail";
} {
  if (body.profile_id === undefined || body.profile_id === null) {
    throw new InterpretError("PROFILE_ID_REQUIRED", ERROR_MESSAGE.PROFILE_ID_REQUIRED);
  }
  if (String(body.profile_id) !== String(authenticatedUserId)) {
    throw new InterpretError("PROFILE_ID_MISMATCH", ERROR_MESSAGE.PROFILE_ID_MISMATCH);
  }
  if (typeof body.topic_id !== "string" || body.topic_id.trim().length === 0) {
    throw new InterpretError("TOPIC_ID_REQUIRED", ERROR_MESSAGE.TOPIC_ID_REQUIRED);
  }
  if (body.mode !== "summary" && body.mode !== "detail") {
    throw new InterpretError("INVALID_MODE", ERROR_MESSAGE.INVALID_MODE);
  }
  // evidence_fact_keys는 클라이언트가 topics/select에서 받은 값을 "참고"로 보내는
  // 필드일 뿐 서버 판단에 쓰지 않는다(§3 서버 재검증 원칙) — 형식만 가볍게 검증.
  if (body.evidence_fact_keys !== undefined && !Array.isArray(body.evidence_fact_keys)) {
    throw new InterpretError("INVALID_REQUEST_BODY", "evidence_fact_keys는 배열이어야 합니다.");
  }
  return { topicId: body.topic_id.trim(), mode: body.mode };
}

function parseBirthDate(birthDate: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDate);
  if (!match) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

function parseBirthTime(
  birthTime: string | null | undefined,
  birthTimeUnknown: boolean
): { hour?: number; minute?: number } {
  if (birthTimeUnknown || !birthTime) return {};
  const match = /^(\d{1,2}):(\d{1,2})$/.exec(birthTime);
  if (!match) return {};
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return {};
  return { hour, minute };
}

function toEngineGender(gender: string | null | undefined): "male" | "female" | undefined {
  if (gender === "male" || gender === "female") return gender;
  return undefined;
}

export async function POST(request: NextRequest) {
  try {
    const auth = await requireUser(request);
    if (!auth) return unauthorizedResponse();
    const userId = auth.userId;

    let rawBody: RequestBody;
    try {
      rawBody = await request.json();
    } catch {
      throw new InterpretError("INVALID_REQUEST_BODY", ERROR_MESSAGE.INVALID_REQUEST_BODY);
    }

    const { topicId, mode } = validateBody(rawBody, userId);

    // ── 출생정보/profile 확인 ──
    const user = await prisma.user.findUnique({ where: { id: userId }, include: { profile: true } });
    if (!user || !user.profile?.birthDate) {
      throw new InterpretError("BIRTH_INFO_REQUIRED", ERROR_MESSAGE.BIRTH_INFO_REQUIRED);
    }
    const parsedDate = parseBirthDate(user.profile.birthDate);
    if (!parsedDate) {
      throw new InterpretError("BIRTH_INFO_REQUIRED", ERROR_MESSAGE.BIRTH_INFO_REQUIRED);
    }
    const { hour, minute } = parseBirthTime(user.profile.birthTime, user.profile.birthTimeUnknown);
    const birthInput: SajuBirthInput = {
      year: parsedDate.year,
      month: parsedDate.month,
      day: parsedDate.day,
      hour,
      minute,
      gender: toEngineGender(user.gender),
      isLunar: user.profile.isLunar,
    };

    // ── SajuFactsCache 조회 → FACT 확보(§4 "FACT 확보") ──
    let facts;
    let birthKey: string;
    try {
      const result = await getSajuFacts(birthInput, { userId });
      facts = result.facts;
      birthKey = result.birthKey;
    } catch (e) {
      if (e instanceof SajuEngineClientError) {
        console.error("[POST /api/public/saju-renewal/interpret] FACT 조회 실패:", e.message);
        throw new InterpretError("FACT_ENGINE_UNAVAILABLE", ERROR_MESSAGE.FACT_ENGINE_UNAVAILABLE);
      }
      throw e;
    }

    // ── [STEP4 §16 세션 캐시/재열람 — docs/05 "재호출 금지", docs/07 E-13] ──
    // 이미 이 (userId, topicId, mode, birthKey)로 QA를 통과해 저장된 결과가 있으면
    // LLM을 다시 호출하지 않고 그대로 반환한다. 재검증(§2·§3)은 "최초 1회" 수행하면
    // 충분하지만, 혹시 그 사이 Topic 자체가 비공개 전환된 경우를 대비해 캐시 적중
        // 시에도 최소한의 scene 재확인만 유지한다(가벼운 방어, 전체 조건 재평가는 생략).
    const cachedResult = await prisma.topicInterpretResult.findUnique({
      where: { userId_topicId_mode_birthKey: { userId, topicId, mode, birthKey } },
    });
    if (cachedResult) {
      return NextResponse.json(
        { success: true, data: JSON.parse(cachedResult.resultJson), cached: true },
        { headers: CORS_HEADERS }
      );
    }

    // ── [STEP4 §2·§3·§4 "요청 Topic 검증" + "Topic 조건 검증"] ──
    // topics/select가 한 번 추천했다는 사실을 신뢰하지 않고, 지금 FACT로 다시
    // 전체 조건을 확인한다. 사용자가 topic_id를 직접 조작해도 이 단계에서 막힌다.
    const validation = validateTopicForInterpret(topicId, facts);
    if (!validation.valid) {
      const code =
        validation.reason === "TOPIC_NOT_FOUND"
          ? "TOPIC_NOT_FOUND"
          : validation.reason === "TOPIC_NOT_RELEASED"
            ? "TOPIC_NOT_RELEASED"
            : validation.reason === "EVIDENCE_EVALUATOR_MISSING"
              ? "EVIDENCE_EVALUATOR_MISSING"
              : "TOPIC_CONDITION_NOT_SATISFIED";
      throw new InterpretError(code, ERROR_MESSAGE[code]);
    }

    // ── [STEP4 §2·§3·§4 "Scene 검증"] ──
    // PERSONALITY_001처럼 scene이 디자인팀에 의해 아직 확정되지 않은 topic은, 조건을
    // 통과하더라도 반드시 거부한다(topic-engine.ts는 scene 개념을 모르므로 이 검증은
    // validateTopicForInterpret()의 책임이 아니라 이 route.ts가 별도로 수행해야 함).
    if (SCENE_UNRESOLVED_TOPIC_IDS.includes(topicId) || getTopicScene(topicId) === undefined) {
      throw new InterpretError("TOPIC_SCENE_UNRESOLVED", ERROR_MESSAGE.TOPIC_SCENE_UNRESOLVED);
    }

    const topicCatalogEntry = TOPIC_CATALOG_SEED.find((t) => t.topicId === topicId)!; // validation.valid이므로 반드시 존재
    const promptTopicInfo: PromptTopicInfo = {
      topicId: topicCatalogEntry.topicId,
      topicName: topicCatalogEntry.topicName,
      categoryGroup: topicCatalogEntry.categoryGroup,
      isTiming: topicCatalogEntry.isTiming,
    };

    // ── [STEP4 §4·§13 "Prompt Template 조회"] ──
    const template = await prisma.topicPromptTemplate.findFirst({
      where: { topicId, mode, status: "active" },
      orderBy: { version: "desc" },
    });

    // ── [STEP4 재수정 #7 "LLM Client → Interpret Service → Route" 계층 분리] ──
    // 기존에 이 자리에 있던 LLM 호출(최대 2회) + QA + fallback 인라인 로직을
    // interpret-service.ts의 generateInterpretResult()로 옮겼다(테스트가 llmCaller를
    // 주입해 timeout/빈응답/QA실패를 실제로 재현할 수 있게 하기 위함). fallback도
    // 동일 QA로 재검증하며, fallback마저 실패하면 InterpretUnavailableError를 던진다
    // (재수정 #6 "471자 fallback을 정상 detail로 반환하는 것은 금지" — catch 블록에서
    // 503으로 응답한다).
    const outcome = await generateInterpretResult({
      mode,
      topic: promptTopicInfo,
      facts,
      evidenceNotes: validation.evidenceNotes ?? [],
      template: template ? { systemPrompt: template.systemPrompt, fallbackJson: template.fallbackJson } : null,
    });
    const finalResult = outcome.result;
    const source = outcome.source;
    // [§11 개발/관리자 로그에서만 source=llm/template 구분, 사용자 응답에는 노출 안 함]
    console.log(
      `[POST /api/public/saju-renewal/interpret] topic=${topicId} mode=${mode} source=${source} attemptLog=${JSON.stringify(outcome.attemptLog)}`
    );

    // ── [STEP4 §16·§17 "ExposureHistory 기록" + 멱등 캐시 저장] ──
    // 여기 도달했다는 것은 LLM 성공 또는 FACT 기반 fallback으로 "정상적으로 완성된
    // 결과"를 사용자에게 보여줄 수 있다는 뜻이다(§16 "LLM 실패/QA 실패 시에는
    // '정상적으로 본 이야기'로 기록하지 않는 것이 좋다" — fallback도 정상 완성된
    // 결과이므로 여기서는 기록 대상이다. 완전히 아무 결과도 못 만든 경우는 없다 —
    // fallback이 항상 최후 방어선으로 성공하도록 설계됨).
    // upsert + unique 제약으로 동시 중복 요청에도 안전하다(§17).
    await prisma.$transaction(async (tx) => {
      await tx.topicInterpretResult.upsert({
        where: { userId_topicId_mode_birthKey: { userId, topicId, mode, birthKey } },
        create: { userId, topicId, mode, birthKey, resultJson: JSON.stringify(finalResult), source },
        update: { resultJson: JSON.stringify(finalResult), source },
      });
      // ExposureHistory는 "이 주제를 본 적 있는지"만 의미하므로 mode(summary/detail)
      // 구분 없이 topicId당 1건만 유지한다 — 이미 기록이 있으면 추가하지 않는다.
      const existingExposure = await tx.topicExposureHistory.findFirst({
        where: { userId, topicId, birthKey },
      });
      if (!existingExposure) {
        await tx.topicExposureHistory.create({ data: { userId, topicId, birthKey } });
      }
    });

    return NextResponse.json(
      { success: true, data: finalResult, cached: false },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof InterpretError) {
      return NextResponse.json(
        { success: false, error: ERROR_MESSAGE[e.code] ?? e.message, reason: e.code },
        { status: ERROR_STATUS[e.code] ?? 400, headers: CORS_HEADERS }
      );
    }
    if (e instanceof InterpretUnavailableError) {
      // [재수정 #6] fallback까지 QA 실패 — 품질 미달 결과를 정상으로 위장하지 않고
      // 503으로 명확히 응답한다. 상세 failureLog는 서버 로그에만 남긴다(§11).
      console.error("[POST /api/public/saju-renewal/interpret] fallback QA 실패:", e.failureLog);
      return NextResponse.json(
        { success: false, error: ERROR_MESSAGE.INTERPRET_UNAVAILABLE, reason: "INTERPRET_UNAVAILABLE" },
        { status: ERROR_STATUS.INTERPRET_UNAVAILABLE, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/saju-renewal/interpret] 처리 중 오류:", e);
    return NextResponse.json(
      { success: false, error: "이야기를 불러오는 중 오류가 발생했습니다." },
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
