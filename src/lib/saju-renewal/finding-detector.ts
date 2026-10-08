// [정통사주 LLM 해석 공통 스펙 v2.0 — §5 "동적 주제 도출(사주 → finding → 주제명)"]
// TK-3 + TK-10 구현: finding 검출기(엔진 규칙 기반) + 주제 파생기.
//
// [역할 분담 확정 — §5 원문] "finding 검출 = 엔진(규칙 기반)이 전담하고, LLM은 제목
// 표현과 서술만 담당한다. 즉 LLM은 finding을 만들지 않는다 — findings는 facts와
// 함께 프롬프트에 입력으로 주입된다." 이 파일은 그 "엔진(규칙 기반)" 역할 전부를
// 구현한다 — LLM을 호출하지 않고(기존 topic-engine.ts와 동일한 LLM 미사용 원칙),
// SajuV3Facts만 입력받아 순수 함수로 finding 배열을 산출한다.
//
// [기존 29종 고정 카탈로그와의 관계 — 아키텍처 통합 결정]
// 기존 topic-catalog-data.ts(29종)는 "이 주제가 존재할 수 있는가"를 평가하는 정적
// 카탈로그이고, topic-evidence.ts는 그 29종 각각의 "조건 충족 여부"를 계산한다.
// v2.0 스펙의 finding은 이와 다른 레이어 — "이 사람 사주에서 실제로 강조할 만한
// 구체적 사실(구간·강도·시제)이 무엇인가"를 가리키는 더 세밀한 단위다. 이번
// TK-3/TK-10 구현은 기존 29종 체계를 대체하지 않고(점수화·노출이력·시기형 1개 제한
// 등 기존 운영 로직을 깨지 않기 위해), 시기(timing) 계열 주제가 실제로 해석될 때
// 그 주제의 "전제(premise)"로 쓸 finding을 추가로 산출하는 보강 레이어로 둔다.
// 즉: topic-engine.ts가 "어떤 topicId를 보여줄지" 결정하고(기존 그대로), 이 파일은
// "그 topicId가 시기를 다루는 주제라면, 그 주제의 구체적 근거가 되는 finding은
// 무엇인가"를 추가로 계산해 interpret-prompt.ts/interpret-verification-gate.ts에
// 공급한다. 이렇게 하면 기존 29종 파이프라인(selectTopics 등)을 깨지 않고도 §5 C6
// "주제 전제 근거"를 전 시기형 주제에 적용할 수 있다.
//
// [finding code — §5.2 표 그대로] STRONGEST_DAEUN / WEAKEST_DAEUN / WEALTH_WINDOW /
// RELATION_WINDOW / HEALTH_RISK / SINSAL_PRESENT.
import type { SajuV3Facts } from "./saju-facts-types";
import { buildDaeunTimeline, type DaeunTense, type DaeunTimelineEntry } from "./daeun-timeline";
import {
  countTenGodGroup,
  TEN_GOD_GROUPS,
  resolveTenGodElements,
  splitGanZhiKr,
} from "./bazi-elements";

export type FindingCode =
  | "STRONGEST_DAEUN"
  | "WEAKEST_DAEUN"
  | "WEALTH_WINDOW"
  | "RELATION_WINDOW"
  | "HEALTH_RISK"
  | "SINSAL_PRESENT";

/** §5.2 findings 스키마 원문 그대로. */
export interface Finding {
  finding_id: string;
  code: FindingCode;
  subject: "self";
  span: {
    ganzhi: string; // 한글 간지(예: "병오") — 엔진 표기를 그대로 쓴다(한자 변환은 표시 레이어 책임).
    from: number;
    to: number;
    age_korean: [number, number];
  };
  /** 0~1 강조도. */
  strength: number;
  tense: DaeunTense;
  /** facts 내 근거 위치(§5.2 "daeun[3]","yongsin" 등 — 사람이 읽을 수 있는 경로 표기). */
  evidence_refs: string[];
}

/** [용신/오행 강도 산출] 일간 기준 재성 오행과 용신/희신이 일치하는 구간을 "재물 기운이
 * 강한 구간"(WEALTH_WINDOW)으로 본다 — topic-evidence.ts evalMONEY_004와 동일한 상생상극
 * 역산 로직을 재사용한다(새 판단 로직 추가 없음, 기존 bazi-elements.ts 함수 그대로 호출). */
function elementMatchesEntry(entry: DaeunTimelineEntry, element: string | undefined): boolean {
  if (!element) return false;
  const parsed = splitGanZhiKr(entry.ganZhiKr);
  return parsed?.ganElement === element || parsed?.zhiElement === element;
}

/** 구간 강도(strength) — 용신/희신 일치 시 가중, 그 외 중립값. 0~1로 clamp. */
function computeStrength(matchesYong: boolean, matchesHee: boolean): number {
  if (matchesYong) return 0.95;
  if (matchesHee) return 0.75;
  return 0.4;
}

function daeunIndexLabel(entries: DaeunTimelineEntry[], target: DaeunTimelineEntry): string {
  const idx = entries.indexOf(target);
  return `daeun[${idx}]`;
}

/**
 * [STRONGEST_DAEUN / WEAKEST_DAEUN] "용신 오행이 들어오는 대운 구간"을 가장 강한
 * 구간으로, "기신(용신과 반대) 오행만 들어오고 용신/희신이 전혀 없는 구간"을 가장
 * 약한 구간으로 본다. §2.2 재현 사례(병오 38~48세, tense:past)가 정확히 이 code다.
 */
function detectDaeunStrengthFindings(facts: SajuV3Facts): Finding[] {
  const timeline = buildDaeunTimeline(facts);
  if (timeline.entries.length === 0) return [];

  const yong = facts.yongshin?.yong;
  const hee = facts.yongshin?.hee;
  const gi = facts.yongshin?.gi;

  let strongest: { entry: DaeunTimelineEntry; strength: number } | null = null;
  let weakest: { entry: DaeunTimelineEntry; strength: number } | null = null;

  for (const entry of timeline.entries) {
    const matchesYong = elementMatchesEntry(entry, yong);
    const matchesHee = elementMatchesEntry(entry, hee);
    const matchesGi = elementMatchesEntry(entry, gi);
    const strength = computeStrength(matchesYong, matchesHee);

    if (!strongest || strength > strongest.strength) {
      strongest = { entry, strength };
    }
    // 약한 구간: 기신 오행만 걸리고 용신/희신이 전혀 없는 구간 중 가장 뚜렷한 것.
    if (matchesGi && !matchesYong && !matchesHee) {
      const weakStrength = 0.9; // "약함"의 강조도 자체는 높게(뚜렷하게 약한 구간이라는 의미)
      if (!weakest || weakStrength > weakest.strength) {
        weakest = { entry, strength: weakStrength };
      }
    }
  }

  const findings: Finding[] = [];
  if (strongest) {
    findings.push({
      finding_id: `F_STRONGEST_${strongest.entry.ganZhiKr}`,
      code: "STRONGEST_DAEUN",
      subject: "self",
      span: {
        ganzhi: strongest.entry.ganZhiKr,
        from: strongest.entry.startYear,
        to: strongest.entry.endYear,
        age_korean: [strongest.entry.startAge, strongest.entry.endAge],
      },
      strength: strongest.strength,
      tense: strongest.entry.tense,
      evidence_refs: [daeunIndexLabel(timeline.entries, strongest.entry), "yongsin"],
    });
  }
  if (weakest) {
    findings.push({
      finding_id: `F_WEAKEST_${weakest.entry.ganZhiKr}`,
      code: "WEAKEST_DAEUN",
      subject: "self",
      span: {
        ganzhi: weakest.entry.ganZhiKr,
        from: weakest.entry.startYear,
        to: weakest.entry.endYear,
        age_korean: [weakest.entry.startAge, weakest.entry.endAge],
      },
      strength: weakest.strength,
      tense: weakest.entry.tense,
      evidence_refs: [daeunIndexLabel(timeline.entries, weakest.entry), "gisin"],
    });
  }
  return findings;
}

/** [WEALTH_WINDOW] 재성 오행(일간 기준 역산)이 용신/희신과 일치하는 가장 가까운
 * 미래/현재 구간. topic-evidence.ts evalMONEY_004와 동일 오행 역산을 재사용. */
function detectWealthWindowFinding(facts: SajuV3Facts): Finding | null {
  const timeline = buildDaeunTimeline(facts);
  if (timeline.entries.length === 0) return null;
  const wealthElement = resolveTenGodElements(facts.day_master?.element)["재성"];
  if (!wealthElement) return null;
  const yongOrHee = [facts.yongshin?.yong, facts.yongshin?.hee].filter(Boolean) as string[];
  if (!yongOrHee.includes(wealthElement)) return null;

  // now/future 구간 중 재성 오행과 겹치는 첫 구간(가장 가까운 구간) 우선.
  const candidates = timeline.entries.filter(
    (e) => (e.tense === "now" || e.tense === "future") && elementMatchesEntry(e, wealthElement)
  );
  const chosen = candidates[0] ?? timeline.entries.find((e) => elementMatchesEntry(e, wealthElement));
  if (!chosen) return null;

  return {
    finding_id: `F_WEALTH_${chosen.ganZhiKr}`,
    code: "WEALTH_WINDOW",
    subject: "self",
    span: {
      ganzhi: chosen.ganZhiKr,
      from: chosen.startYear,
      to: chosen.endYear,
      age_korean: [chosen.startAge, chosen.endAge],
    },
    strength: 0.8,
    tense: chosen.tense,
    evidence_refs: [daeunIndexLabel(timeline.entries, chosen), "yongsin", "ten_gods"],
  };
}

/** [RELATION_WINDOW] 비겁/인성 비중이 뚜렷하거나 합(合)이 많은 구간 — 단순화해
 * "용신/희신과 일치 + 인성·비겁 그룹이 존재"하는 now/future 구간으로 판정한다
 * (topic-evidence.ts evalRELATION_001의 합/인성/비겁 신호를 재사용). */
function detectRelationWindowFinding(facts: SajuV3Facts): Finding | null {
  const timeline = buildDaeunTimeline(facts);
  if (timeline.entries.length === 0) return null;
  const resource = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["인성"]);
  const peer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["비겁"]);
  if (resource.count === 0 && peer.count === 0) return null;

  const yong = facts.yongshin?.yong;
  const hee = facts.yongshin?.hee;
  const candidates = timeline.entries.filter(
    (e) =>
      (e.tense === "now" || e.tense === "future") &&
      (elementMatchesEntry(e, yong) || elementMatchesEntry(e, hee))
  );
  const chosen = candidates[0];
  if (!chosen) return null;

  return {
    finding_id: `F_RELATION_${chosen.ganZhiKr}`,
    code: "RELATION_WINDOW",
    subject: "self",
    span: {
      ganzhi: chosen.ganZhiKr,
      from: chosen.startYear,
      to: chosen.endYear,
      age_korean: [chosen.startAge, chosen.endAge],
    },
    strength: 0.7,
    tense: chosen.tense,
    evidence_refs: [daeunIndexLabel(timeline.entries, chosen), "relations", "ten_gods"],
  };
}

/** [HEALTH_RISK] 일간 극단 강약(과강/과약) + 기신 오행이 들어오는 구간을 건강 주의
 * 구간으로 본다. day_master_strength_score가 없으면(엔진이 값을 안 줬으면) 생성하지
 * 않는다(facts-only, §4-C1).
 *
 * [스케일 확인 — 버그 수정 2026-10-08] saju_engine 실제 응답(/tmp/sample_facts.json)을
 * 직접 확인한 결과 `day_master_strength_score`는 0~1이 아니라 **0~100** 점 스케일이다
 * (예: 신강 79점). topic-evidence.ts도 값 존재 여부만 확인할 뿐 임계값을 쓰지 않아
 * 기존 코드에서 스케일 오염이 드러나지 않았었다. 최초 구현 시 0.8/0.2(0~1 스케일)로
 * 잘못 가정해 HEALTH_RISK가 항상 미검출되는 버그가 있었음 — 0~100 스케일로 수정. */
function detectHealthRiskFinding(facts: SajuV3Facts): Finding | null {
  const timeline = buildDaeunTimeline(facts);
  if (timeline.entries.length === 0) return null;
  const score = facts.day_master_strength_score;
  if (typeof score !== "number") return null;
  const EXTREME_HIGH = 80; // 0~100 스케일 — 과강(身强)
  const EXTREME_LOW = 20; // 0~100 스케일 — 과약(身弱)
  const isExtreme = score >= EXTREME_HIGH || score <= EXTREME_LOW;
  if (!isExtreme) return null;

  const gi = facts.yongshin?.gi;
  const candidates = timeline.entries.filter(
    (e) => (e.tense === "now" || e.tense === "future") && elementMatchesEntry(e, gi)
  );
  const chosen = candidates[0];
  if (!chosen) return null;

  return {
    finding_id: `F_HEALTH_${chosen.ganZhiKr}`,
    code: "HEALTH_RISK",
    subject: "self",
    span: {
      ganzhi: chosen.ganZhiKr,
      from: chosen.startYear,
      to: chosen.endYear,
      age_korean: [chosen.startAge, chosen.endAge],
    },
    strength: 0.65,
    tense: chosen.tense,
    evidence_refs: [daeunIndexLabel(timeline.entries, chosen), "gisin", "day_master_strength_score"],
  };
}

/** [SINSAL_PRESENT] facts.sinsal 배열에 실제로 값이 있을 때만 생성(§5.5 특수 케이스
 * "finding SINSAL_*의 facts.sinsal만 인용" — SINSAL_HALLUCINATION 검사 대상). 시기와
 * 무관하므로 span은 현재 대운 구간(있으면)으로 채우고 tense는 "now"로 고정한다. */
function detectSinsalPresentFinding(facts: SajuV3Facts): Finding | null {
  const sinsalList = facts.sinsal ?? [];
  if (sinsalList.length === 0) return null;
  const timeline = buildDaeunTimeline(facts);
  const current = timeline.currentEntry;
  const span = current
    ? { ganzhi: current.ganZhiKr, from: current.startYear, to: current.endYear, age_korean: [current.startAge, current.endAge] as [number, number] }
    : { ganzhi: facts.pillars?.day?.kr ?? "", from: 0, to: 0, age_korean: [0, 0] as [number, number] };

  return {
    finding_id: `F_SINSAL_${sinsalList[0]}`,
    code: "SINSAL_PRESENT",
    subject: "self",
    span,
    strength: 0.6,
    tense: "now",
    evidence_refs: ["sinsal"],
  };
}

/**
 * [메인 엔트리 — TK-3/TK-10] facts에서 findings 전체를 검출한다. LLM을 호출하지
 * 않는 순수 함수이며, 같은 facts 입력에는 항상 같은 findings를 반환한다(재요청
 * 불변성 — topic-engine.ts selectTopics()와 동일 설계 원칙).
 */
export function detectFindings(facts: SajuV3Facts): Finding[] {
  const findings: Finding[] = [];
  findings.push(...detectDaeunStrengthFindings(facts));
  const wealth = detectWealthWindowFinding(facts);
  if (wealth) findings.push(wealth);
  const relation = detectRelationWindowFinding(facts);
  if (relation) findings.push(relation);
  const health = detectHealthRiskFinding(facts);
  if (health) findings.push(health);
  const sinsal = detectSinsalPresentFinding(facts);
  if (sinsal) findings.push(sinsal);
  return findings;
}

/** topicId(기존 29종)에 가장 적합한 finding code를 매핑한다 — §5 C6 "주제 전제 근거"를
 * 기존 29종 카탈로그 위에 얹기 위한 보강 매핑. 시기형(isTiming=true) 주제만 매핑을
 * 가지며, 시기와 무관한 주제(PERSONALITY_001 등)는 premise_ref가 필요 없다(§1 매트릭스
 * "성격·기질: 기간 앵커링 면제 가능"). */
const TOPIC_TO_FINDING_CODE: Record<string, FindingCode> = {
  LIFE_001: "STRONGEST_DAEUN",
  LIFE_002: "STRONGEST_DAEUN",
  LIFE_003: "STRONGEST_DAEUN",
  LIFE_004: "STRONGEST_DAEUN",
  LIFE_006: "STRONGEST_DAEUN",
  MONEY_004: "WEALTH_WINDOW",
  TALENT_004: "STRONGEST_DAEUN",
  TALENT_005: "STRONGEST_DAEUN",
  LOVE_005: "RELATION_WINDOW",
  LOVE_006: "RELATION_WINDOW",
};

/** [TK-8 — §8.5 sinsal 게이트 프로파일 매핑] topic-catalog-data.ts의 requiredFacts
 * 열을 전수 조사해 "신살"을 실제로 언급하는 topicId만 뽑았다(RELATION_002:
 * "귀인계 신살 · 용신 오행", LOVE_006: "배우자성 대운 · 도화" — 도화도 신살의
 * 한 종류). 이 두 topicId로 해석을 생성할 때만 interpret-verification-gate.ts의
 * checkSinsalHallucination()(gateProfile==="sinsal"에서만 활성화)이 작동해야
 * facts.sinsal에 없는 신살명(예: 화개·역마 등)을 LLM이 지어내는 것을 차단할 수
 * 있다. interpret-service.ts의 resolveGateProfile()이 이 집합을 참조한다.
 *
 * [버그 발견 경위] checkSinsalHallucination() 자체와 GateProfile="sinsal" 타입은
 * TK-2(커밋 4f5df89)에서 이미 구현되고 dev-test-verification-gate.ts 단위
 * 테스트도 통과했지만, 이 매핑이 없어 interpret-service.ts의 resolveGateProfile()이
 * 모든 topicId에 대해 "time_scoped"|"no_time"만 반환했다 — 즉 실제 해석 생성
 * 경로에서는 sinsal 게이트가 단 한 번도 호출되지 않는 사각지대였다. */
export const SINSAL_GATE_TOPIC_IDS = new Set<string>(["RELATION_002", "LOVE_006"]);

/**
 * [findForTopic] interpret route.ts가 "이번 topicId 해석에 전제로 쓸 finding 1개"를
 * 조회할 때 쓰는 헬퍼. 매핑이 없거나(시기 무관 주제) 해당 code의 finding이 이 사람
 * 사주에 없으면(§4-C6 "전제가 facts로 뒷받침되지 않으면 생성 금지") null을 반환한다 —
 * 호출부는 null이면 C2/C6 앵커링·전제 검증을 건너뛴다(§1 매트릭스의 "면제 가능").
 */
export function findForTopic(topicId: string, facts: SajuV3Facts): Finding | null {
  const code = TOPIC_TO_FINDING_CODE[topicId];
  if (!code) return null;
  const findings = detectFindings(facts);
  // strength 내림차순으로 가장 뚜렷한 finding을 전제로 선택(동점이면 배열 순서 유지).
  const matched = findings.filter((f) => f.code === code).sort((a, b) => b.strength - a.strength);
  return matched[0] ?? null;
}
