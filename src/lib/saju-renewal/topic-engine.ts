// [정통사주 리뉴얼 v1.0] Topic Engine — 최종지시서 §8 "Topic Engine 최종 규칙(구현
// 계약)" 파이프라인의 순수 함수 구현.
//
// [LLM 미사용 원칙] 이 파일은 LLM을 호출하지 않는다(지시서 전역 원칙 — "LLM이
// 사주계산/사실생성/후보임의생성 절대 금지", §8 "LLM 호출 없음"). 입력은 오직
// saju_engine이 이미 계산한 `/saju/v3/facts` 응답과, 호출부가 조회해 전달하는
// 노출 이력뿐이다.
//
// [순수 함수 설계 — 재요청 불변성] §8 "재요청 불변성: 같은 사주·같은 이력이면 동일
// 결과(완전 결정론) — 후보 재요청 시 재계산 없음." 이를 보장하기 위해 이 파일의
// 핵심 함수 selectTopics()는 DB를 직접 읽거나 쓰지 않는다 — 노출 이력은 호출부
// (API route)가 조회해서 인자로 넘기고, 선정된 주제를 exposure_history에 기록하는
// 것도 호출부의 책임이다. 같은 facts + 같은 exposureHistory 입력이면 항상 같은
// 출력이 나온다(Date.now() 등 비결정적 값은 novelty 계산에만 쓰이고, 그 계산도
// "지금 시각"을 인자로 받아 주입할 수 있게 해 테스트에서 고정 가능하다).
import { TOPIC_CATALOG_SEED, TopicCatalogSeedItem, TIMING_TOPIC_IDS } from "./topic-catalog-data";
import { TOPIC_EVIDENCE_EVALUATORS, EvidenceCheck } from "./topic-evidence";
import type { SajuV3Facts } from "./saju-facts-types";
import {
  SCORING_WEIGHTS,
  DEFAULT_INTEREST_LEVEL,
  TIMING_RELEVANCE_WHEN_MATCHED,
  TIMING_RELEVANCE_WHEN_NEUTRAL,
  resolveNoveltyWeight,
  CATEGORY_BALANCE_FRESH,
  CATEGORY_BALANCE_DUPLICATE,
  MIN_SATISFIED_EVIDENCE_COUNT,
  CONFIDENCE_GUARDRAIL_MIN,
  MIN_EVIDENCE_FOR_INTERPRETATION,
  NEXT_CANDIDATES_MIN,
  NEXT_CANDIDATES_MAX,
  DUPLICATE_FACT_OVERLAP_THRESHOLD,
  DUPLICATE_FACT_PENALTY_MAGNITUDE,
} from "./topic-scoring-config";

/** §10 "fact_schema_version=1.0" — /saju/v3/facts 캐시와 동일 값을 응답에 포함. */
export const FACT_SCHEMA_VERSION = "1.0";

/** 호출부(API route)가 TopicExposureHistory에서 조회해 넘기는 최소 정보. */
export interface ExposureRecord {
  topicId: string;
  /** 가장 최근 노출 시각(동일 topicId가 여러 번 있으면 호출부가 최신 1건만 넘긴다). */
  viewedAt: Date;
}

export interface SelectTopicsInput {
  facts: SajuV3Facts;
  /** 이 사용자가 이 birthKey로 이미 본 주제 이력(topic-engine은 읽기만 함, 기록은 호출부 책임). */
  exposureHistory: ExposureRecord[];
  /** 테스트/재현성을 위해 "지금 시각"을 주입할 수 있게 한다. 기본값은 실제 현재 시각. */
  now?: Date;
  /**
   * [범용 제외 목록 — scene 개념을 엔진에 들이지 않는 순수 필터] 호출부(API 계층)가
   * "이번 선정 풀에 절대 포함되면 안 되는 topic_id"를 넘긴다. 이 배열이 왜 제외되는지
   * (예: docs/11 계약의 scene이 아직 디자인팀에 의해 확정되지 않음, 또는 §2
   * exclude_topic_ids처럼 이번 세션에서 이미 노출된 주제)는 topic-engine.ts가 알 필요가
   * 없다 — "증거/점수/노출이력과 무관하게 애초에 후보가 될 수 없는 ID"라는 동일한
   * 의미로만 다룬다. 2025 진행 승인 지시 §4 "처음부터 사용자 후보군에서 제외하는 것이
   * 정확하다"를 반영 — ②평가 단계(evaluations 수집) 자체에서 걸러내 점수 계산조차
   * 하지 않는다(단, 폴백 LIFE_000은 ⑤ 단계의 "후보 0건 구조적 불가" 보장과 충돌하므로
   * 이 목록에 넣어도 무시한다 — 서비스 안정성이 더 중요한 보장 조건).
   */
  excludeTopicIds?: string[];
}

export interface TopicCandidateResult {
  topicId: string;
  title: string;
  categoryGroup: string;
  isTiming: boolean;
  isFallback: boolean;
  score: number;
  evidenceFactKeys: string[];
  /** §8 응답 계약 "basis(data/basis)" — data: 통과한 evidence factKey, basis: 서술형 근거 note. */
  basis: { data: string[]; basis: string[] };
}

export interface SelectTopicsResult {
  /** 오늘의 주제(§10 "오늘의 주제 1"). 후보가 구조적으로 0건이 될 수 없음(폴백 보장). */
  todayTopic: TopicCandidateResult;
  /** 다음 후보 3~4개(§8 "최종 1건 + 다음 후보 3~4"). */
  nextCandidates: TopicCandidateResult[];
  factSchemaVersion: string;
}

interface InternalEvaluation {
  topic: TopicCatalogSeedItem;
  checks: EvidenceCheck[];
  satisfiedChecks: EvidenceCheck[];
  requiredCount: number;
  passesConditionCheck: boolean;
  avgConfidence: number;
  novelty: number;
  /** 가장 최근 노출로부터 7일 미만(감쇠표 최저 구간) — §8 "노출 이력 필터"가 하드 제외 대상으로 쓴다. */
  recentlyShown: boolean;
}

function average(nums: number[]): number {
  if (nums.length === 0) return 0;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

/**
 * [1단계: Fact 존재 확인] facts 자체가 비어있거나 핵심 블록이 전혀 없으면 — 계산이
 * 실패했거나 saju_facts 캐시가 손상된 상태다. 이런 경우 29종 주제 판정 자체가
 * 무의미하므로, 호출부가 이 값으로 "폴백만 반환"할지 판단할 수 있게 한다.
 *
 * [해석 가용성 — §8 "해석용 Fact 3개 미만 주제는 점수 무관 후보 제외"의 구현 선택]
 * 이 규칙은 "주제별 세부 Fact 개수"로 더 정밀하게 쪼갤 수도 있으나, 29종 모두 공통
 * L1 코어 블록(pillars/day_master/yongshin 등)에서 파생되므로, 세션 전체 단위로
 * "해석에 쓸 수 있는 최소 Fact 블록 수"를 게이트하는 것으로 구현한다(개별 주제마다
 * 다른 민감도를 주는 것은 과설계로 판단 — 완통읽기 §6에 기록된 구현자 결정 범위).
 */
export function countCoreFactBlocks(facts: SajuV3Facts): number {
  const blocks = [
    facts.pillars,
    facts.day_master,
    facts.five_elements_weighted,
    facts.ten_gods,
    facts.yongshin,
    facts.luck_pillars && facts.luck_pillars.length > 0 ? facts.luck_pillars : undefined,
    facts.current_luck,
    facts.relations,
    facts.sinsal && facts.sinsal.length > 0 ? facts.sinsal : undefined,
    facts.twelve_stages,
  ];
  return blocks.filter((b) => b !== undefined && b !== null).length;
}

/** §8 조건 검증: 충족 근거 ≥2(요건 개수보다 적은 주제는 그 전체 개수를 요구) + confidence 가드레일. */
function evaluateTopic(topic: TopicCatalogSeedItem, facts: SajuV3Facts): InternalEvaluation | null {
  const evaluator = TOPIC_EVIDENCE_EVALUATORS[topic.topicId];
  if (!evaluator) return null; // 29종 전부 topic-evidence.ts에 구현되어 있어야 함(방어적 null 처리).

  const checks = evaluator(facts);
  const satisfiedChecks = checks.filter((c) => c.satisfied);
  // [특이 조건 주제 처리] checks.length가 2 미만인 주제(예: LOVE_004/005, TALENT_004 —
  // 지시서가 "특이 조건"이라 명시한 단일 하드게이트형)는 "근거 ≥2"를 구조적으로 만족할
  // 수 없다. 이 경우 지시서 취지("아니면 미노출")를 살려 "정의된 체크 전부 충족"을
  // 요구한다 — 실질적으로 ≥2 규칙의 하한을 checks.length로 클램프한 것.
  const requiredCount = Math.min(MIN_SATISFIED_EVIDENCE_COUNT, checks.length);
  const passesCount = satisfiedChecks.length >= requiredCount && requiredCount > 0;
  const avgConfidence = average(satisfiedChecks.map((c) => c.confidence));
  const passesConfidence = topic.isFallback || avgConfidence >= CONFIDENCE_GUARDRAIL_MIN;

  return {
    topic,
    checks,
    satisfiedChecks,
    requiredCount,
    passesConditionCheck: topic.isFallback || (passesCount && passesConfidence),
    avgConfidence,
    novelty: 1, // placeholder, resolveExposure()에서 덮어씀
    recentlyShown: false,
  };
}

/** 노출 이력에서 topicId별 가장 최근 조회 시각만 추려 Map으로 정리한다. */
function latestExposureByTopic(history: ExposureRecord[]): Map<string, Date> {
  const map = new Map<string, Date>();
  for (const rec of history) {
    const prev = map.get(rec.topicId);
    if (!prev || rec.viewedAt > prev) map.set(rec.topicId, rec.viewedAt);
  }
  return map;
}

/** §8 점수식: score = 0.35E + 0.20I + 0.20T + 0.15N + 0.10B − P. */
function computeScore(params: {
  evidenceStrength: number; // E: 0~1
  timingRelevance: number; // T: 0~1
  novelty: number; // N: 0~1
  categoryBalance: number; // B: 0 or 1
  duplicatePenalty: number; // P: 0 or DUPLICATE_FACT_PENALTY_MAGNITUDE
}): number {
  const { evidenceStrength, timingRelevance, novelty, categoryBalance, duplicatePenalty } = params;
  return (
    SCORING_WEIGHTS.evidenceStrength * evidenceStrength +
    SCORING_WEIGHTS.interestLevel * DEFAULT_INTEREST_LEVEL +
    SCORING_WEIGHTS.timingRelevance * timingRelevance +
    SCORING_WEIGHTS.novelty * novelty +
    SCORING_WEIGHTS.categoryBalance * categoryBalance -
    duplicatePenalty
  );
}

/** [P: Fact 70% 중복 페널티] 이미 선택된 후보(들)의 evidenceFactKeys와 70% 이상
 * 겹치면 패널티를 부여한다 — "다른 주제인데 같은 근거로만 이야기가 반복되는" 상황 방지. */
function computeDuplicatePenalty(
  candidateKeys: string[],
  alreadyPickedKeySets: string[][]
): number {
  if (candidateKeys.length === 0 || alreadyPickedKeySets.length === 0) return 0;
  for (const pickedKeys of alreadyPickedKeySets) {
    if (pickedKeys.length === 0) continue;
    const overlap = candidateKeys.filter((k) => pickedKeys.includes(k)).length;
    const overlapRatio = overlap / candidateKeys.length;
    if (overlapRatio >= DUPLICATE_FACT_OVERLAP_THRESHOLD) {
      return DUPLICATE_FACT_PENALTY_MAGNITUDE;
    }
  }
  return 0;
}

/** §동점 처리 규칙(디자인팀 승인조건①): sortOrder 오름차순 → topicId 사전순. */
function compareTopicsForTie(a: TopicCatalogSeedItem, b: TopicCatalogSeedItem): number {
  const aIndex = TOPIC_CATALOG_SEED.indexOf(a);
  const bIndex = TOPIC_CATALOG_SEED.indexOf(b);
  if (aIndex !== bIndex) return aIndex - bIndex; // 배열 선언 순서 = sortOrder(0~28)
  return a.topicId.localeCompare(b.topicId);
}

function toCandidateResult(evaluation: InternalEvaluation, score: number): TopicCandidateResult {
  const { topic, satisfiedChecks } = evaluation;
  return {
    topicId: topic.topicId,
    title: topic.topicName,
    categoryGroup: topic.categoryGroup,
    isTiming: topic.isTiming,
    isFallback: topic.isFallback,
    score,
    evidenceFactKeys: satisfiedChecks.map((c) => c.factKey),
    basis: {
      data: satisfiedChecks.map((c) => c.factKey),
      basis: satisfiedChecks.map((c) => c.note),
    },
  };
}

/**
 * [Topic Engine 메인 파이프라인] §8 원문 순서를 그대로 구현:
 * Fact 존재 확인 → 조건 검증(≥2, confidence 가드레일) → 점수화 → 노출 이력 필터 →
 * 시기형 1개 하드 제한 → 폴백 보장(LIFE_000 상시 후보) → 최종 1건 + 다음 후보 3~4.
 */
export function selectTopics(input: SelectTopicsInput): SelectTopicsResult {
  const { facts, exposureHistory, now = new Date(), excludeTopicIds = [] } = input;
  const exposureMap = latestExposureByTopic(exposureHistory);

  // ① Fact 존재 확인 — 코어 블록이 너무 적으면 폴백만 유효한 주제로 취급한다.
  const coreFactBlocks = countCoreFactBlocks(facts);
  const interpretable = coreFactBlocks >= MIN_EVIDENCE_FOR_INTERPRETATION;

  // ② 조건 검증 — 29종 전부 평가(릴리즈phase와 무관하게 평가는 전부 수행하고,
  // 노출 대상 필터링은 release_phase 체크로 별도 처리한다 — 1차 릴리즈는 phase 1만 노출).
  const evaluations: InternalEvaluation[] = [];
  for (const topic of TOPIC_CATALOG_SEED) {
    if (topic.releasePhase !== 1 && !topic.isFallback) continue; // 1차 릴리즈 노출 대상만(§7)
    // [처음부터 후보군에서 제외 — 2025 진행 승인 지시 §4] 폴백은 "후보 0건 구조적
    // 불가" 보장이 우선이므로 제외 목록을 무시한다.
    if (!topic.isFallback && excludeTopicIds.includes(topic.topicId)) continue;
    const evalResult = evaluateTopic(topic, facts);
    if (!evalResult) continue;
    if (!topic.isFallback && !interpretable) continue; // 해석 가용성 미달 → 폴백 제외 전부 탈락
    if (!evalResult.passesConditionCheck) continue;

    // [폴백 novelty는 일반 주제와 동일 공식 적용] 폴백(LIFE_000)이 "상시 후보"인 것은
    // ⑤ 단계(풀에서 제외되지 않도록 보장)의 의미이고, N(신규성) 점수 자체는 일반 주제와
    // 같은 노출 이력 감쇠 공식을 그대로 적용해야 한다 — 그래야 "이미 본 이야기는 후순위"
    // (지시서 5장) 원칙이 폴백에도 동일하게 작동해, 최근에 본 폴백이 매번 1위로 고정되는
    // 것을 방지한다.
    const lastViewed = exposureMap.get(topic.topicId) ?? null;
    const novelty = resolveNoveltyWeight(lastViewed, now);
    const elapsedDays = lastViewed ? (now.getTime() - lastViewed.getTime()) / (1000 * 60 * 60 * 24) : Infinity;
    evaluations.push({ ...evalResult, novelty, recentlyShown: elapsedDays < 7 });
  }

  // ③ 노출 이력 필터 — "7일 미만(최근에 봄)" 주제는 이번 선정 풀에서 제외한다
  // (§8 "노출 이력... 7일 0.05"가 사실상 0에 가까운 최저 구간이라는 점, 그리고 5장
  // "이미 본 이야기 제외/후순위" 요구를 "제외"로 적용). 단, 폴백(LIFE_000)은 예외 —
  // 폴백은 "후보 0건 구조적 불가" 보장 역할이라 노출 이력과 무관하게 항상 유지한다.
  let pool = evaluations.filter((e) => e.topic.isFallback || !e.recentlyShown);

  // ④ 시기형 1개 하드 제한 — 시기형 후보가 여러 개면 "증거 강도(E)"가 가장 높은
  // 1개만 남기고 나머지는 이번 선정에서 제외한다(세션당 최대 1개, §7 각주).
  const timingPool = pool.filter((e) => TIMING_TOPIC_IDS.includes(e.topic.topicId));
  if (timingPool.length > 1) {
    timingPool.sort((a, b) => b.satisfiedChecks.length - a.satisfiedChecks.length || compareTopicsForTie(a.topic, b.topic));
    const keepTimingId = timingPool[0].topic.topicId;
    pool = pool.filter((e) => !TIMING_TOPIC_IDS.includes(e.topic.topicId) || e.topic.topicId === keepTimingId);
  }

  // ⑤ 폴백 보장 — LIFE_000이 ②~④ 단계에서 어떤 이유로든 풀에 없다면 강제로 추가한다
  // ("후보 0건 구조적 불가"를 코드로 보장).
  const fallbackTopic = TOPIC_CATALOG_SEED.find((t) => t.isFallback);
  if (fallbackTopic && !pool.some((e) => e.topic.isFallback)) {
    const fallbackEval = evaluateTopic(fallbackTopic, facts);
    if (fallbackEval) {
      pool.push({ ...fallbackEval, novelty: 1, recentlyShown: false });
    }
  }

  // 풀이 완전히 비는 것은 폴백 보장 단계 덕분에 발생할 수 없다 — 방어적으로만 체크.
  if (pool.length === 0) {
    throw new Error(
      "[topic-engine] 후보 풀이 비었습니다 — LIFE_000 폴백 보장 로직이 깨졌을 가능성이 있습니다."
    );
  }

  // ⑥ 최종 선정 — E(근거강도)만 우선 계산해 그리디로 1건(오늘의 주제)을 뽑고,
  // 이후 B(카테고리밸런스)를 매 선택마다 재계산하며 다음 후보 3~4개를 순차 선정한다.
  const remaining = [...pool];
  const picked: { evaluation: InternalEvaluation; result: TopicCandidateResult }[] = [];
  const pickedCategoryGroups: string[] = [];
  const pickedKeySets: string[][] = [];

  const maxPicks = 1 + NEXT_CANDIDATES_MAX; // 오늘의 주제 1 + 다음 후보 최대 4
  while (remaining.length > 0 && picked.length < maxPicks) {
    let bestIndex = 0;
    let bestScore = -Infinity;
    const scored: { index: number; score: number }[] = [];

    remaining.forEach((evaluation, index) => {
      const totalChecks = evaluation.checks.length;
      const evidenceStrength = totalChecks > 0 ? evaluation.satisfiedChecks.length / totalChecks : 0;
      const isTiming = evaluation.topic.isTiming;
      const timingRelevance = isTiming ? TIMING_RELEVANCE_WHEN_MATCHED : TIMING_RELEVANCE_WHEN_NEUTRAL;
      const categoryBalance = pickedCategoryGroups.includes(evaluation.topic.categoryGroup)
        ? CATEGORY_BALANCE_DUPLICATE
        : CATEGORY_BALANCE_FRESH;
      const candidateKeys = evaluation.satisfiedChecks.map((c) => c.factKey);
      const duplicatePenalty = computeDuplicatePenalty(candidateKeys, pickedKeySets);

      const score = computeScore({
        evidenceStrength,
        timingRelevance,
        novelty: evaluation.novelty,
        categoryBalance,
        duplicatePenalty,
      });
      scored.push({ index, score });
    });

    // 최고점 선택, 동점이면 §동점규칙(sortOrder→topicId) 적용.
    scored.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return compareTopicsForTie(remaining[a.index].topic, remaining[b.index].topic);
    });
    bestIndex = scored[0].index;
    bestScore = scored[0].score;

    const chosenEvaluation = remaining[bestIndex];
    picked.push({ evaluation: chosenEvaluation, result: toCandidateResult(chosenEvaluation, bestScore) });
    pickedCategoryGroups.push(chosenEvaluation.topic.categoryGroup);
    pickedKeySets.push(chosenEvaluation.satisfiedChecks.map((c) => c.factKey));
    remaining.splice(bestIndex, 1);
  }

  const todayPick = picked[0];
  let nextPicks = picked.slice(1);
  // §8 "다음 후보 3~4" — 최소 3개를 못 채우면(=전체 주제 풀이 작음) 있는 만큼만 반환한다
  // (29종 카탈로그+노출필터 특성상 정상 운영에서는 거의 항상 3개 이상 확보됨). 운영 모니터링을
  // 위해 최소 기준(NEXT_CANDIDATES_MIN) 미달 여부만 debug 로그로 남긴다(사용자 노출 없음).
  if (nextPicks.length > NEXT_CANDIDATES_MAX) nextPicks = nextPicks.slice(0, NEXT_CANDIDATES_MAX);
  if (nextPicks.length < NEXT_CANDIDATES_MIN && process.env.NODE_ENV !== "production") {
    console.debug(
      `[topic-engine] 다음 후보가 ${nextPicks.length}개뿐입니다(기준 ${NEXT_CANDIDATES_MIN}~${NEXT_CANDIDATES_MAX}) — 노출 이력 필터가 과도하게 좁혔을 수 있습니다.`
    );
  }

  return {
    todayTopic: todayPick.result,
    nextCandidates: nextPicks.map((p) => p.result),
    factSchemaVersion: FACT_SCHEMA_VERSION,
  };
}

// 테스트/디버깅 용으로 내부 비교 함수도 함께 노출(단위 테스트에서 동점 규칙만 검증할 때 사용).
export { compareTopicsForTie };
