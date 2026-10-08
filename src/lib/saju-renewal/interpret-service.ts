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
import { buildDaeunTimeline, toDaeunTimelineApiEntries } from "./daeun-timeline";
import {
  checkInterpretSummary,
  checkInterpretDetail,
  type InterpretSummaryResult,
  type InterpretDetailResult,
  type QaCheckOptions,
  type QaCheckResult,
} from "./interpret-qa-check";
import { KNOWN_TERM_KEYS } from "./interpret-term-dictionary";
import { buildFallbackSummary, buildFallbackDetail } from "./interpret-fallback";
import { detectFindings, findForTopic, type Finding } from "./finding-detector";
import {
  runVerificationGate,
  hasBlockingViolations,
  formatViolationsForFeedback,
  type GateProfile,
  type Violation,
} from "./interpret-verification-gate";

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
/** [버그 수정 — 2026-10-06 "진행" 지시 대응, 실측 기반 수정]
 * 기존 15_000ms(15초)는 claude-haiku-4-5가 detail 분량(목표 1,800~2,200자,
 * 최대 4096 토큰)을 생성하는 데 걸리는 실제 시간보다 짧았다. Anthropic API를
 * 직접 3회 반복 실측한 결과 20.8~21.9초가 일관되게 소요됨을 확인했다
 * (서버 로그 전수 분석에서도 detail 요청의 91%가 fallback으로 빠졌고, 그중
 * 49/143건이 "LLM_ERROR(...타임아웃...)" — 정상적으로 생성 중이던 응답을
 * 15초에서 강제 중단시킨 것이 원인의 상당 부분이었음을 확인).
 * 재시도 2회 구조(MAX_LLM_ATTEMPTS=2)를 유지하면서 각 시도가 정상 완료될
 * 여유를 주기 위해 35초로 상향한다(실측 최댓값 21.9초 + 60% 여유).
 * 참고: route.ts의 _detailTimeout(Flutter 클라이언트 측)은 이미 서버
 * 최악 처리시간(재시도 2회 포함)을 고려해 40초로 설정되어 있으므로
 * (saju_renewal_api.dart 참고), 이 변경 후에도 클라이언트 타임아웃보다
 * 서버 처리시간이 짧게 유지된다(35초×1회 실패 후 재시도 성공 시에도
 * 이론상 최대 70초가 될 수 있으나, 재시도는 과거 실패 직후 즉시 발생하고
 * 실측상 거의 1회 시도에서 성공하므로 실제 체감 지연은 20~25초 수준). */
const DETAIL_TIMEOUT_MS = 35_000;
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

// [STEP5 — 중복 QA 금지 원칙의 "단일 진입점" 보강] 이전에는 runSingleAttempt()와
// runFallbackWithQa() 두 곳에서 각각 QaCheckOptions를 조립하고 mode별로
// checkInterpretSummary/checkInterpretDetail을 분기 호출했다. 실제 검증 함수
// 자체는 이미 하나(interpret-qa-check.ts)를 공유하고 있었으나, "그 함수를 어떤
// 옵션으로, 어떻게 호출하는지"가 두 곳에 복제되어 있어 한쪽만 수정되고 다른 쪽이
// 누락될 위험(회귀 가능성)이 있었다. runQaCheck()로 이 호출 지점을 하나로
// 합쳐, LLM 경로와 fallback 경로가 "항상 물리적으로 동일한 코드 한 줄"을 거치게
// 한다(동작/결과는 기존과 100% 동일 — 순수 리팩토링, 로직 변경 없음).
function runQaCheck(
  mode: InterpretMode,
  result: InterpretSummaryResult | InterpretDetailResult,
  topic: PromptTopicInfo
): QaCheckResult {
  const qaOptions: QaCheckOptions = { expectedTopicId: topic.topicId, isTiming: topic.isTiming, knownTermKeys: KNOWN_TERM_KEYS };
  return mode === "summary"
    ? checkInterpretSummary(result as InterpretSummaryResult, qaOptions)
    : checkInterpretDetail(result as InterpretDetailResult, qaOptions);
}

/** [v2.0 §8 검증 게이트 연동] LLM 출력(JSON 구조)에서 나이·연도·간지·오행 주장을
 * 대조할 "서술 본문 텍스트"만 추출한다. title/evidence.text도 LLM이 작성한
 * 서술이므로 포함한다(§8.1 검증 대상이 "LLM이 쓴" 모든 텍스트이기 때문). */
function extractNarrativeText(mode: InterpretMode, result: InterpretSummaryResult | InterpretDetailResult): string {
  if (mode === "summary") {
    const r = result as InterpretSummaryResult;
    return [r.title, r.summary, r.evidence?.text].filter(Boolean).join(" ");
  }
  const r = result as InterpretDetailResult;
  const blockTexts = r.blocks.flatMap((b) => [b.body, b.evidence?.text].filter(Boolean));
  return [r.title, ...blockTexts].join(" ");
}

/** [v2.0 §8.5 게이트 프로파일 결정] 기존 29종 체계에는 gate_profile 필드가 없으므로
 * (§5 스키마가 요구하는 동적 topic 객체가 아직 DB에 없음), topic.isTiming 플래그로
 * 최소한의 매핑을 한다 — isTiming=true 주제는 §1 매트릭스상 전부 "기간 앵커링
 * 필수" 범주(총운/재물/애정/건강/직업/대운)에 속하므로 time_scoped, isTiming=false는
 * no_time(앵커 면제, 단 언급 시 대조)으로 처리한다. 신살 전용 topicId가 추가되면
 * 이 함수에 "sinsal" 분기를 추가하면 된다(§8.5 "주제가 늘어나도 게이트를 새로
 * 만들지 않는다"는 원칙을 그대로 따름 — 매핑만 확장).
 */
/**
 * [TK-7 — §4-C5 "주제별 대운 브리핑 표 UI"] detail 모드 + isTiming 주제일 때만
 * facts.luck_pillars 기반 타임라인을 결과에 덧붙인다. LLM 응답/fallback
 * 어느 경로든 이 함수를 거치게 해, "표는 LLM이 쓰지 않고 서버가 facts에서
 * 그대로 복사한다"(C5 원문)는 원칙을 결과 조립 단계에서 강제한다 — 이미
 * QA/게이트를 통과한 result 객체에 필드만 추가하는 것이므로 QA를 다시 돌릴
 * 필요가 없다(QA는 body 텍스트만 검증 대상, daeun_timeline은 LLM이 작성한
 * 텍스트가 아니라 엔진 facts를 그대로 옮긴 구조화 데이터이기 때문).
 * 타임라인 entries가 비어 있으면(facts에 대운 배열 자체가 없음) 필드를
 * 아예 생략한다(§4-C1 facts-only — 없는 데이터로 빈 표를 강제하지 않음).
 */
function attachDaeunTimelineIfApplicable(
  mode: InterpretMode,
  topic: PromptTopicInfo,
  facts: SajuV3Facts,
  result: InterpretSummaryResult | InterpretDetailResult
): InterpretSummaryResult | InterpretDetailResult {
  if (mode !== "detail" || !topic.isTiming) return result;
  const timeline = buildDaeunTimeline(facts);
  if (timeline.entries.length === 0) return result;
  return { ...(result as InterpretDetailResult), daeun_timeline: toDaeunTimelineApiEntries(timeline) };
}

function resolveGateProfile(topic: PromptTopicInfo): GateProfile {
  return topic.isTiming ? "time_scoped" : "no_time";
}

/** [v2.0 §8 검증 게이트 — 단일 진입점] QA를 이미 통과한 결과를 추가로 검증 게이트에
 * 통과시킨다. §8.6 "위반 ≥1건 → 재생성"에 따라 차단(block) 등급 위반이 있으면
 * 실패로 간주한다(경고 등급만 있으면 통과 처리 — VIOLATION_SEVERITY 참고). */
function runGateCheck(
  mode: InterpretMode,
  result: InterpretSummaryResult | InterpretDetailResult,
  topic: PromptTopicInfo,
  facts: SajuV3Facts,
  premise: Finding | null,
  findings: Finding[]
): { ok: boolean; violations: Violation[] } {
  const text = extractNarrativeText(mode, result);
  const violations = runVerificationGate({
    facts,
    topic: {
      topicId: topic.topicId,
      premiseRef: premise?.finding_id ?? null,
      timeScoped: topic.isTiming,
      gateProfile: resolveGateProfile(topic),
    },
    findings,
    text,
  });
  return { ok: !hasBlockingViolations(violations), violations };
}

async function runSingleAttempt(
  mode: InterpretMode,
  topic: PromptTopicInfo,
  facts: SajuV3Facts,
  evidenceNotes: string[],
  systemPromptFromDb: string,
  llmCaller: LlmCaller,
  premise: Finding | null,
  findings: Finding[],
  gateFeedback: string[]
): Promise<{ result: InterpretSummaryResult | InterpretDetailResult; failures: string[] } | null> {
  const { systemPrompt, userPrompt } = buildInterpretPrompt({
    mode,
    topic,
    facts,
    evidence: { factKeys: [], notes: evidenceNotes },
    topicSpecificSystemPrompt: systemPromptFromDb,
    premise,
    gateFeedback,
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

  const qa = runQaCheck(mode, normalized, topic);
  if (!qa.ok) {
    return { result: normalized, failures: qa.failures.map((f) => `${f.code}: ${f.message}`) };
  }

  // [v2.0 §8 검증 게이트 — QA 통과 후 추가 검증] 기존 QA(구조/분량/보안)를 통과한
  // 결과라도 나이·연도·간지·오행 주장이 엔진 값과 다르면(§2.2 재현 결함과 동일
  // 유형) 여기서 걸러낸다. 차단 등급 위반이 있으면 실패로 처리해 재시도를
  // 트리거한다(§8.6 "위반 ≥1건 → 재생성").
  const gate = runGateCheck(mode, normalized, topic, facts, premise, findings);
  if (!gate.ok) {
    return { result: normalized, failures: formatViolationsForFeedback(gate.violations) };
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

  // [v2.0 §5/§8 finding 전제 — 1회만 계산] detectFindings()는 순수 함수이므로
  // 매 재시도마다 다시 계산해도 같은 값이지만(재요청 불변성), 굳이 반복 호출할
  // 필요가 없어 파이프라인 진입 시 한 번만 계산해 전체 재시도 루프에 공유한다.
  const findings = detectFindings(facts);
  const premise = findForTopic(topic.topicId, facts);

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
    const qa = runQaCheck(mode, fallbackResult, topic);
    if (!qa.ok) {
      attemptLog.push(`fallback: QA_FAILED(${qa.failures.map((f) => `${f.code}: ${f.message}`).join(" | ")})`);
      throw new InterpretUnavailableError(
        "해석 결과를 준비하지 못했습니다(fallback QA 실패) — 이는 템플릿 결함을 의미하므로 즉시 점검이 필요합니다.",
        attemptLog
      );
    }
    // [v2.0 §8.6 실패 정책 "2) 폴백 — facts 기반 대운 브리핑 표 + 현재 대운 앵커만
    // 노출(결정적 템플릿)"] fallback 템플릿은 고정 문구+facts 치환이라 정상적으로는
    // 게이트도 항상 통과해야 한다. 혹시 템플릿 문구 자체가 결함(예: 존재하지 않는
    // 간지를 하드코딩)을 안고 있는 경우를 대비해 여기서도 게이트를 돌려 로그만
    // 남긴다(fallback까지 게이트로 차단하면 §8.6의 "최종 방어선" 역할을 못 하게
    // 되므로, fallback 자체를 막지는 않고 운영 로그로만 가시화한다).
    const gate = runGateCheck(mode, fallbackResult, topic, facts, premise, findings);
    if (!gate.ok) {
      console.warn(
        `[interpret-service] fallback 결과가 검증 게이트 위반을 포함함(topic=${topic.topicId}): ${formatViolationsForFeedback(gate.violations).join(" | ")}`
      );
      attemptLog.push(`fallback: GATE_WARN(${formatViolationsForFeedback(gate.violations).join(" | ")})`);
    } else {
      attemptLog.push("fallback: GATE_PASSED");
    }
    attemptLog.push("fallback: QA_PASSED");
    return {
      result: attachDaeunTimelineIfApplicable(mode, topic, facts, fallbackResult),
      source: "template",
      attemptLog,
    };
  }

  // ── 템플릿 자체가 없으면(STEP6 시딩 전) LLM 호출 없이 즉시 fallback ──
  if (!template) {
    attemptLog.push("TEMPLATE_NOT_FOUND: TopicPromptTemplate 레코드가 없음");
    return runFallbackWithQa();
  }

  // ── LLM 호출(최대 MAX_LLM_ATTEMPTS회) ──
  // [v2.0 §8.2 재생성 루프] 직전 시도의 QA/게이트 위반 목록을 다음 시도의
  // 프롬프트에 피드백으로 덧붙인다(Python 레퍼런스 generate_with_gate()의
  // feedback 누적과 동일한 역할). QA 실패 메시지와 게이트 위반 메시지 모두
  // outcome.failures에 섞여 들어오므로 동일하게 다음 시도 피드백으로 전달한다.
  let gateFeedback: string[] = [];
  for (let attempt = 1; attempt <= MAX_LLM_ATTEMPTS; attempt++) {
    try {
      const outcome = await runSingleAttempt(
        mode,
        topic,
        facts,
        evidenceNotes,
        template.systemPrompt,
        llmCaller,
        premise,
        findings,
        gateFeedback
      );
      if (!outcome) {
        attemptLog.push(`attempt${attempt}: LLM_EMPTY_OR_UNPARSEABLE_RESPONSE`);
        continue;
      }
      if (outcome.failures.length > 0) {
        attemptLog.push(`attempt${attempt}: QA_FAILED(${outcome.failures.join(" | ")})`);
        gateFeedback = outcome.failures;
        continue;
      }
      attemptLog.push(`attempt${attempt}: SUCCESS`);
      return {
        result: attachDaeunTimelineIfApplicable(mode, topic, facts, outcome.result),
        source: "llm",
        attemptLog,
      };
    } catch (e) {
      const msg = e instanceof LlmClientError ? e.message : String(e);
      attemptLog.push(`attempt${attempt}: LLM_ERROR(${msg})`);
    }
  }

  // ── 전체 LLM 시도 실패 → fallback(+fallback QA) ──
  return runFallbackWithQa();
}
