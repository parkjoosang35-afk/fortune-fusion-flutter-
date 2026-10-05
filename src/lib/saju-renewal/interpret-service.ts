// [정통사주 리뉴얼 v1.0 — STEP 4 재수정] Interpret 서비스 계층.
//
// [재수정 배경 — 개발자 지시 #7 "LLM Client → Interpret Service → Route"]
// 기존에는 route.ts 안에 LLM 호출(completeText 직접 import) + 재시도 + fallback
// 로직이 전부 인라인으로 박혀 있어, CASE 7(timeout)/8(빈 응답)/9(QA 실패)를 실제로
// 재현하는 테스트가 불가능했다(route.ts가 Next.js Request/Response에 묶여 있고
// completeText를 직접 import하므로 모킹 지점이 없었음). 이 파일은 그 로직을
// Next.js와 완전히 독립된 순수 함수로 분리해, llmCaller를 주입할 수 있게 한다 —
// 운영 코드는 기본값(completeText)을 쓰고, 테스트 코드는 가짜 llmCaller를 주입해
// timeout/빈 응답/QA 실패를 실제로 강제 재현한다.
//
// [fallback도 반드시 QA를 통과해야 함 — 개발자 지시 #6]
// 이전 구조: LLM 실패 → fallback → (QA 없이) 바로 사용자 응답.
// 수정 구조: LLM 실패 → fallback 생성 → **같은 checkInterpretSummary/Detail로 QA
// 재실행** → 통과해야만 사용자 응답. fallback도 QA를 통과하지 못하면(이론상 거의
// 발생하지 않도록 템플릿을 고정 설계했지만, 혹시 모를 결함을 대비해) 정상 결과로
// 위장하지 않고 InterpretUnavailableError를 던져 route.ts가 503로 명확히 응답한다
// (지시 #6 "471자 fallback을 정상 detail로 반환하는 것은 금지").
//
// [중복 QA 금지 — 지시 #15] LLM 경로와 fallback 경로가 완전히 동일한
// checkInterpretSummary/checkInterpretDetail(interpret-qa-check.ts)을 공유한다.
// 이 파일 자체는 새로운 QA 규칙을 만들지 않는다.
import type { SajuV3Facts } from "./saju-facts-types";
import { completeText, LlmClientError } from "@/lib/llm-client";
import { buildInterpretPrompt, type PromptTopicInfo, type InterpretMode } from "./interpret-prompt";
import {
  checkInterpretSummary,
  checkInterpretDetail,
  type InterpretSummaryResult,
  type InterpretDetailResult,
  type QaCheckOptions,
} from "./interpret-qa-check";
import { KNOWN_TERM_KEYS } from "./interpret-term-dictionary";
import { buildFallbackSummary, buildFallbackDetail } from "./interpret-fallback";

/** [모킹 지점] route.ts의 completeText 호출과 동일한 시그니처. 테스트는 이 타입과
 * 호환되는 가짜 함수를 llmCaller로 주입해 timeout/빈응답/비정상JSON을 재현한다. */
export type LlmCaller = (params: {
  systemPrompt: string;
  userPrompt: string;
  model?: string;
  timeoutMs?: number;
  maxTokens?: number;
  temperature?: number;
}) => Promise<string>;

/** [STEP4 재수정 — maxTokens 상향] 기존 maxTokens=2200은 한글 토큰화 특성상(한글은
 * 영문보다 글자당 토큰 소모가 많음) 2,000자 이상 응답 시 중간에 잘릴 위험이 있었다.
 * CASE 11에서 실측된 639~839자 응답이 "프롬프트의 블록당 글자수 지시가 작았던 것"이
 * 주원인이지만, 토큰 여유도 함께 넉넉히 둬 JSON이 잘리는 2차 원인을 예방한다. */
const SUMMARY_MAX_TOKENS = 1200;
const DETAIL_MAX_TOKENS = 4096;
const SUMMARY_TIMEOUT_MS = 8_000;
const DETAIL_TIMEOUT_MS = 15_000;
/** [saju-output-spec.pdf §8과 동일한 운영값 재사용] 실패 시 재생성 최대 2회(최초 1 + 재시도 1). */
const MAX_LLM_ATTEMPTS = 2;

export class InterpretUnavailableError extends Error {
  /** fallback까지 QA에 실패한 경우에만 발생 — 이론상 고정 템플릿 설계로는 발생하지
   * 않아야 하나, 혹시 모를 결함(예: 운영 중 DB fallbackJson 오타)을 대비한 최종 방어선. */
  readonly failureLog: string[];
  constructor(message: string, failureLog: string[]) {
    super(message);
    this.name = "InterpretUnavailableError";
    this.failureLog = failureLog;
  }
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

function normalizeSummaryJson(parsed: unknown, topicId: string): InterpretSummaryResult | null {
  if (typeof parsed !== "object" || parsed === null) return null;
  const p = parsed as Record<string, unknown>;
  if (typeof p.title !== "string" || typeof p.summary !== "string") return null;
  const evidence = p.evidence as Record<string, unknown> | undefined;
  if (!evidence || typeof evidence.text !== "string") return null;
  const type = evidence.type === "elements" || evidence.type === "luck" ? evidence.type : "grid";
  return {
    topic_id: topicId,
    title: p.title,
    summary: p.summary,
    evidence: {
      type,
      text: evidence.text,
      cols: Array.isArray(evidence.cols) ? (evidence.cols as number[]) : undefined,
      hl: evidence.hl as string | number | undefined,
    },
    source: "llm",
  };
}

function normalizeDetailJson(parsed: unknown, topicId: string): InterpretDetailResult | null {
  if (typeof parsed !== "object" || parsed === null) return null;
  const p = parsed as Record<string, unknown>;
  if (typeof p.title !== "string" || !Array.isArray(p.blocks)) return null;
  const blocks = p.blocks
    .map((b): InterpretDetailResult["blocks"][number] | null => {
      if (typeof b !== "object" || b === null) return null;
      const bb = b as Record<string, unknown>;
      const n = bb.n;
      if (n !== 1 && n !== 2 && n !== 3 && n !== 4 && n !== 5) return null;
      if (typeof bb.body !== "string") return null;
      const evidence = bb.evidence as Record<string, unknown> | undefined;
      const timing = bb.timing as Record<string, unknown> | undefined;
      return {
        n,
        body: bb.body,
        evidence:
          evidence && typeof evidence.text === "string"
            ? { type: evidence.type === "elements" || evidence.type === "luck" ? evidence.type : "grid", text: evidence.text }
            : undefined,
        timing: timing && typeof timing.luck_index === "number" ? { luck_index: timing.luck_index } : undefined,
      };
    })
    .filter((b): b is InterpretDetailResult["blocks"][number] => b !== null);
  return { topic_id: topicId, title: p.title, blocks, source: "llm" };
}

export interface GenerateInterpretParams {
  mode: InterpretMode;
  topic: PromptTopicInfo;
  facts: SajuV3Facts;
  evidenceNotes: string[];
  /** DB에서 조회한 TopicPromptTemplate 레코드(없으면 null — 즉시 fallback). */
  template: { systemPrompt: string; fallbackJson: string | null } | null;
  /** [테스트 전용 모킹 지점] 생략 시 실제 completeText(Anthropic API)를 사용한다. */
  llmCaller?: LlmCaller;
}

export interface GenerateInterpretOutcome {
  result: InterpretSummaryResult | InterpretDetailResult;
  source: "llm" | "template";
  /** 운영 로그/디버깅용 — 사용자 응답에는 절대 포함하지 않는다(§11). */
  attemptLog: string[];
}

async function runSingleAttempt(
  mode: InterpretMode,
  topic: PromptTopicInfo,
  facts: SajuV3Facts,
  evidenceNotes: string[],
  systemPromptFromDb: string,
  llmCaller: LlmCaller
): Promise<{ result: InterpretSummaryResult | InterpretDetailResult; failures: string[] } | null> {
  const { systemPrompt, userPrompt } = buildInterpretPrompt({
    mode,
    topic,
    facts,
    evidence: { factKeys: [], notes: evidenceNotes },
    topicSpecificSystemPrompt: systemPromptFromDb,
  });
  const raw = await llmCaller({
    systemPrompt,
    userPrompt,
    maxTokens: mode === "summary" ? SUMMARY_MAX_TOKENS : DETAIL_MAX_TOKENS,
    temperature: 0.7,
    timeoutMs: mode === "summary" ? SUMMARY_TIMEOUT_MS : DETAIL_TIMEOUT_MS,
  });
  // [CASE 8 "빈 응답" 방어] LLM이 빈 문자열/공백만 반환하면 즉시 실패로 처리한다.
  if (!raw || raw.trim().length === 0) {
    return null;
  }
  const parsed = extractJsonObject(raw);
  const normalized =
    mode === "summary" ? (parsed ? normalizeSummaryJson(parsed, topic.topicId) : null) : parsed ? normalizeDetailJson(parsed, topic.topicId) : null;
  if (!normalized) return null;

  const qaOptions: QaCheckOptions = { expectedTopicId: topic.topicId, isTiming: topic.isTiming, knownTermKeys: KNOWN_TERM_KEYS };
  const qa = mode === "summary" ? checkInterpretSummary(normalized as InterpretSummaryResult, qaOptions) : checkInterpretDetail(normalized as InterpretDetailResult, qaOptions);
  if (!qa.ok) {
    return { result: normalized, failures: qa.failures.map((f) => `${f.code}: ${f.message}`) };
  }
  return { result: normalized, failures: [] };
}

/**
 * [핵심 파이프라인 — STEP4 §4·§14·§15 + 재수정 #6] LLM 호출(최대 2회 재시도) → QA →
 * 실패 시 fallback 생성 → **fallback도 동일 QA로 재검증** → 통과한 결과만 반환한다.
 * fallback마저 QA를 통과하지 못하면 InterpretUnavailableError를 던진다(사용자에게
 * 품질 미달 결과를 "정상"으로 위장해 보여주지 않기 위함).
 */
export async function generateInterpretResult(params: GenerateInterpretParams): Promise<GenerateInterpretOutcome> {
  const { mode, topic, facts, evidenceNotes, template, llmCaller = completeText } = params;
  const attemptLog: string[] = [];

  function buildFallbackResult(): InterpretSummaryResult | InterpretDetailResult {
    return mode === "summary"
      ? buildFallbackSummary({
          topicId: topic.topicId,
          topicName: topic.topicName,
          evidenceNotes,
          fallbackJson: template?.fallbackJson ?? null,
        })
      : buildFallbackDetail({
          topicId: topic.topicId,
          topicName: topic.topicName,
          evidenceNotes,
          isTiming: topic.isTiming,
          fallbackJson: template?.fallbackJson ?? null,
        });
  }

  function runFallbackWithQa(): GenerateInterpretOutcome {
    const fallbackResult = buildFallbackResult();
    const qaOptions: QaCheckOptions = { expectedTopicId: topic.topicId, isTiming: topic.isTiming, knownTermKeys: KNOWN_TERM_KEYS };
    const qa =
      mode === "summary"
        ? checkInterpretSummary(fallbackResult as InterpretSummaryResult, qaOptions)
        : checkInterpretDetail(fallbackResult as InterpretDetailResult, qaOptions);
    if (!qa.ok) {
      attemptLog.push(`fallback: QA_FAILED(${qa.failures.map((f) => `${f.code}: ${f.message}`).join(" | ")})`);
      throw new InterpretUnavailableError(
        "해석 결과를 준비하지 못했습니다(fallback QA 실패) — 이는 템플릿 결함을 의미하므로 즉시 점검이 필요합니다.",
        attemptLog
      );
    }
    attemptLog.push("fallback: QA_PASSED");
    return { result: fallbackResult, source: "template", attemptLog };
  }

  // ── 템플릿 자체가 없으면(STEP6 시딩 전) LLM 호출 없이 즉시 fallback ──
  if (!template) {
    attemptLog.push("TEMPLATE_NOT_FOUND: TopicPromptTemplate 레코드가 없음");
    return runFallbackWithQa();
  }

  // ── LLM 호출(최대 MAX_LLM_ATTEMPTS회) ──
  for (let attempt = 1; attempt <= MAX_LLM_ATTEMPTS; attempt++) {
    try {
      const outcome = await runSingleAttempt(mode, topic, facts, evidenceNotes, template.systemPrompt, llmCaller);
      if (!outcome) {
        attemptLog.push(`attempt${attempt}: LLM_EMPTY_OR_UNPARSEABLE_RESPONSE`);
        continue;
      }
      if (outcome.failures.length > 0) {
        attemptLog.push(`attempt${attempt}: QA_FAILED(${outcome.failures.join(" | ")})`);
        continue;
      }
      attemptLog.push(`attempt${attempt}: SUCCESS`);
      return { result: outcome.result, source: "llm", attemptLog };
    } catch (e) {
      const msg = e instanceof LlmClientError ? e.message : String(e);
      attemptLog.push(`attempt${attempt}: LLM_ERROR(${msg})`);
    }
  }

  // ── 전체 LLM 시도 실패 → fallback(+fallback QA) ──
  return runFallbackWithQa();
}
