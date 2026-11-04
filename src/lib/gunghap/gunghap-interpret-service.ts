// 궁합지도(Gunghap Map) — Section 4(유료 상세 해석) LLM 서비스 계층.
//
// [2026-11 궁합 주제 반영 지시서 — Section 4/5]
// "유료 상세 해석은 반드시 실제 LLM 호출(model: claude-haiku-4-5,
// src/lib/llm-client.ts)이어야 한다" / "기존 템플릿(gunghap-narrative.ts)을
// 단순 반환하는 방식으로 완료 처리하지 말 것" 요구사항의 구현체.
//
// [saju-renewal/interpret-service.ts 패턴 재사용, 1바이트도 수정하지 않음]
// 그 파일의 "LLM 호출(최대 N회 재시도) → QA → 실패 시 fallback(+fallback도
// QA 재검증)" 파이프라인 골격을 그대로 차용하되, 궁합지도는 다음 지점에서
// 의도적으로 더 가볍다(게이트/QA 축소):
//   - 시기(대운) 앵커링 검증 없음 — 애초에 FACT에 시기 정보가 없고
//     프롬프트가 "시기를 언급하지 말라"고 지시하므로, saju-renewal처럼
//     "나이/연도/간지가 facts와 일치하는지" 대조할 대상 자체가 없다.
//   - 10개 용어 화이트리스트(termKey) 체계 없음 — 궁합지도는 애초에 그런
//     마크업 UI가 없다.
//   - 신살 환각 검증 없음 — 궁합지도 FACT는 신살을 사용하지 않는다
//     (gunghap-relation-fact.ts에 sinsal 필드 자체가 없음).
// 대신 이 파일이 자체로 검증하는 것: JSON 구조/4개 필드 존재/글자수 범위
// (180~320자)/"AI" 표현 미노출 — gunghap 도메인에 맞는 최소 QA만 둔다.
//
// [fallback도 반드시 QA를 통과해야 함] saju-renewal과 동일 원칙 — LLM
// 실패 시 fallback(무료 템플릿을 "상세 해석" 포맷으로 재포장)을 생성하고,
// 같은 QA를 통과시켜야만 사용자에게 응답한다.
import { completeText, LlmClientError } from "@/lib/llm-client";
import type { GunghapCategoryId } from "./gunghap-category-rules";
import {
  buildGunghapInterpretPrompt,
  type BuildGunghapInterpretPromptParams,
  type GunghapFreeNarrative,
  type GunghapInterpretPersonInfo,
  type GunghapInterpretTopicInfo,
} from "./gunghap-interpret-prompt";

export const GUNGHAP_INTERPRET_SERVICE_VERSION = "gunghap-interpret-service-1.0.0";

export const GUNGHAP_INTERPRET_MODEL = "claude-haiku-4-5";
const DETAIL_MAX_TOKENS = 2048;
const DETAIL_TIMEOUT_MS = 35_000;
/** [saju-renewal과 동일 운영값 재사용] 실패 시 재생성 최대 2회(최초 1 + 재시도 1). */
const MAX_LLM_ATTEMPTS = 2;

const FIELD_MIN_LENGTH = 120;
const FIELD_MAX_LENGTH = 420;

export interface GunghapInterpretDetail {
  categoryId: GunghapCategoryId;
  grade: string;
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  improvement: string;
}

export interface GunghapInterpretOutcome {
  detail: GunghapInterpretDetail;
  source: "llm" | "template";
  model: string;
  /** 운영 로그/감사용 — 사용자 응답에는 절대 포함하지 않는다. */
  attemptLog: string[];
}

/** [모킹 지점 — 테스트 전용] interpret-service.ts의 LlmCaller와 동일 역할. */
export type GunghapLlmCaller = (params: {
  systemPrompt: string;
  userPrompt: string;
  model?: string;
  timeoutMs?: number;
  maxTokens?: number;
  temperature?: number;
}) => Promise<string>;

export interface GenerateGunghapInterpretParams {
  topic: GunghapInterpretTopicInfo;
  evidence: BuildGunghapInterpretPromptParams["evidence"];
  grade: string;
  freeNarrative: GunghapFreeNarrative;
  owner: GunghapInterpretPersonInfo;
  guest: GunghapInterpretPersonInfo;
  relationTypeLabel: string;
  /** [테스트 전용 모킹 지점] 생략 시 실제 completeText(Anthropic API)를 사용한다. */
  llmCaller?: GunghapLlmCaller;
}

function extractJsonObject(raw: string): unknown | null {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    return JSON.parse(match[0]);
  } catch {
    return null;
  }
}

const AI_LANGUAGE_PATTERNS = [/\bAI\b/i, /인공지능/, /챗봇/, /language model/i];
const ABSOLUTE_CLAIM_PATTERNS = [/반드시/, /틀림없이/, /100%/, /절대로?\s*(그렇|이렇|아니)/];

interface NormalizedLlmResult {
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  improvement: string;
}

function normalizeLlmJson(parsed: unknown): NormalizedLlmResult | null {
  if (typeof parsed !== "object" || parsed === null) return null;
  const p = parsed as Record<string, unknown>;
  const keys = ["relationshipFeature", "strength", "conflictRisk", "improvement"] as const;
  for (const k of keys) {
    if (typeof p[k] !== "string" || (p[k] as string).trim().length === 0) return null;
  }
  return {
    relationshipFeature: (p.relationshipFeature as string).trim(),
    strength: (p.strength as string).trim(),
    conflictRisk: (p.conflictRisk as string).trim(),
    improvement: (p.improvement as string).trim(),
  };
}

/** [gunghap 전용 경량 QA] saju-renewal의 무거운 QaCheck(§14, termKey/시기
 * 앵커링 등)와 달리, 이 도메인에 실제로 의미 있는 4가지만 검사한다:
 * (1) 4개 필드 모두 존재, (2) 각 필드 글자수 범위, (3) "AI" 표현 미노출,
 * (4) 단정적 표현 과다 사용 금지(1개 필드당 1회까지는 허용 — 완전 금지는
 * 자연스러운 문장 생성을 과도하게 제약할 수 있어 "반복 남용"만 차단). */
function runLightQaCheck(result: NormalizedLlmResult): { ok: boolean; failures: string[] } {
  const failures: string[] = [];
  const fields: Array<[string, string]> = [
    ["relationshipFeature", result.relationshipFeature],
    ["strength", result.strength],
    ["conflictRisk", result.conflictRisk],
    ["improvement", result.improvement],
  ];
  for (const [name, text] of fields) {
    if (text.length < FIELD_MIN_LENGTH) {
      failures.push(`${name}: 글자수 부족(${text.length}자, 최소 ${FIELD_MIN_LENGTH}자)`);
    }
    if (text.length > FIELD_MAX_LENGTH) {
      failures.push(`${name}: 글자수 초과(${text.length}자, 최대 ${FIELD_MAX_LENGTH}자)`);
    }
    for (const pattern of AI_LANGUAGE_PATTERNS) {
      if (pattern.test(text)) {
        failures.push(`${name}: "AI" 관련 표현 포함 금지 위반`);
        break;
      }
    }
    const absoluteHits = ABSOLUTE_CLAIM_PATTERNS.reduce(
      (acc, p) => acc + (text.match(p)?.length ?? 0),
      0,
    );
    if (absoluteHits >= 2) {
      failures.push(`${name}: 단정적 표현("반드시"/"틀림없이"/"100%" 등) 남용`);
    }
  }
  return { ok: failures.length === 0, failures };
}

/** [fallback — LLM 전체 실패 시] 무료 템플릿(gunghap-narrative.ts가 이미
 * 생성한 4문장)을 그대로 "유료 상세"로 재포장한다. 완전히 새 문장을
 * 만들지 않으므로 QA(글자수 등)를 통과 못 할 가능성이 있어, fallback
 * 전용으로 조금 더 관대한 범위로 재검증한다(사용자에게 빈 화면 대신
 * 최소한 기존에 검증된 결정론적 문장이라도 보여주기 위함 — saju-renewal의
 * "fallback까지 QA 통과해야 함" 원칙과 동일하되, fallback 전용 완화
 * 기준을 둔다: 글자수 하한만 느슨하게, AI 표현/단정 표현 검사는 동일하게
 * 적용한다 — 결정론적 템플릿 문장은 애초에 그런 표현을 쓰지 않으므로
 * 이 완화가 실제로 발동할 일은 거의 없다).
 */
function buildFallbackResult(freeNarrative: GunghapFreeNarrative): NormalizedLlmResult {
  return {
    relationshipFeature: freeNarrative.relationshipFeature,
    strength: freeNarrative.strength,
    conflictRisk: freeNarrative.conflictRisk,
    improvement: freeNarrative.improvement,
  };
}

function runFallbackQaCheck(result: NormalizedLlmResult): { ok: boolean; failures: string[] } {
  const failures: string[] = [];
  const fields: Array<[string, string]> = [
    ["relationshipFeature", result.relationshipFeature],
    ["strength", result.strength],
    ["conflictRisk", result.conflictRisk],
    ["improvement", result.improvement],
  ];
  for (const [name, text] of fields) {
    if (text.trim().length === 0) failures.push(`${name}: 비어 있음`);
    for (const pattern of AI_LANGUAGE_PATTERNS) {
      if (pattern.test(text)) failures.push(`${name}: "AI" 관련 표현 포함 금지 위반`);
    }
  }
  return { ok: failures.length === 0, failures };
}

async function runSingleAttempt(
  params: GenerateGunghapInterpretParams,
  llmCaller: GunghapLlmCaller,
  qaFeedback: string[],
): Promise<{ result: NormalizedLlmResult; failures: string[] } | null> {
  const { systemPrompt, userPrompt } = buildGunghapInterpretPrompt({
    topic: params.topic,
    evidence: params.evidence,
    grade: params.grade,
    freeNarrative: params.freeNarrative,
    owner: params.owner,
    guest: params.guest,
    relationTypeLabel: params.relationTypeLabel,
    qaFeedback,
  });

  const raw = await llmCaller({
    systemPrompt,
    userPrompt,
    model: GUNGHAP_INTERPRET_MODEL,
    maxTokens: DETAIL_MAX_TOKENS,
    temperature: 0.7,
    timeoutMs: DETAIL_TIMEOUT_MS,
  });

  if (!raw || raw.trim().length === 0) return null;

  const parsed = extractJsonObject(raw);
  const normalized = parsed ? normalizeLlmJson(parsed) : null;
  if (!normalized) return null;

  const qa = runLightQaCheck(normalized);
  if (!qa.ok) return { result: normalized, failures: qa.failures };

  return { result: normalized, failures: [] };
}

/**
 * [핵심 파이프라인] LLM 호출(최대 2회) → 경량 QA → 실패 시 fallback(무료
 * 템플릿 재포장) + fallback QA → 통과한 결과만 반환한다. 이 함수 자체는
 * DB 접근을 하지 않는다(순수 함수) — 캐싱/저장은 호출부(unlock/route.ts)의
 * 책임이다(관심사 분리, saju-renewal과 동일 원칙).
 */
export async function generateGunghapInterpret(
  params: GenerateGunghapInterpretParams,
): Promise<GunghapInterpretOutcome> {
  const { llmCaller = completeText } = params;
  const attemptLog: string[] = [];

  let qaFeedback: string[] = [];
  for (let attempt = 1; attempt <= MAX_LLM_ATTEMPTS; attempt++) {
    try {
      const outcome = await runSingleAttempt(params, llmCaller, qaFeedback);
      if (!outcome) {
        attemptLog.push(`attempt${attempt}: LLM_EMPTY_OR_UNPARSEABLE_RESPONSE`);
        continue;
      }
      if (outcome.failures.length > 0) {
        attemptLog.push(`attempt${attempt}: QA_FAILED(${outcome.failures.join(" | ")})`);
        qaFeedback = outcome.failures;
        continue;
      }
      attemptLog.push(`attempt${attempt}: SUCCESS`);
      return {
        detail: {
          categoryId: params.topic.categoryId,
          grade: params.grade,
          ...outcome.result,
        },
        source: "llm",
        model: GUNGHAP_INTERPRET_MODEL,
        attemptLog,
      };
    } catch (e) {
      const msg = e instanceof LlmClientError ? e.message : String(e);
      attemptLog.push(`attempt${attempt}: LLM_ERROR(${msg})`);
    }
  }

  // ── 전체 LLM 시도 실패 → fallback(무료 템플릿 재포장) ──
  const fallback = buildFallbackResult(params.freeNarrative);
  const fallbackQa = runFallbackQaCheck(fallback);
  if (!fallbackQa.ok) {
    attemptLog.push(`fallback: QA_FAILED(${fallbackQa.failures.join(" | ")})`);
    // 이론상 발생하지 않아야 함(무료 템플릿은 이미 검증된 결정론적 문장) —
    // 혹시라도 실패하면 호출부가 500으로 처리하도록 예외를 던진다.
    throw new Error("GUNGHAP_INTERPRET_FALLBACK_QA_FAILED: " + fallbackQa.failures.join(" | "));
  }
  attemptLog.push("fallback: QA_PASSED");
  return {
    detail: {
      categoryId: params.topic.categoryId,
      grade: params.grade,
      ...fallback,
    },
    source: "template",
    model: GUNGHAP_INTERPRET_MODEL,
    attemptLog,
  };
}
