// [정통사주 리뉴얼 v1.0] 29종 주제별 "조건 검증" 구현 — topic-catalog-data.ts의
// `requiredFacts`(지시서 §7 원문 한국어 키워드)를 실제 `/saju/v3/facts` 필드 접근
// 로직으로 번역한다.
//
// [구현자 결정 범위 — 완통읽기 §6 "미해결/진행중" 참고] 지시서는 "충족 근거 ≥2"
// (§8, 숫자 확정) 같은 추상적 기준과 requiredFacts 키워드만 제공하고, "재성 유형·강약"
// 같은 한국어 조건을 "ten_gods에서 편재/정재 슬롯을 세고 비율을 구한다"처럼 구체적
// 필드 접근으로 바꾸는 것은 지시서가 "개발자 임의 결정 금지"라고 못박은 숫자(가중치·
// 임계값)와는 별개 영역이다 — 이는 "어떤 Fact가 어떤 주제의 증거가 되는가"라는
// 자연어→코드 매핑 문제이며, 합리적 범위 내에서 구현자가 결정한다(운영 중 조정 가능하게
// 이 파일 하나로 모아둔다 — TopicCondition 테이블의 conditionValue는 사람이 읽는 설명을
// 보존하고, 실제 판정 로직은 이 파일이 전담).
//
// [설계] 각 주제는 EvidenceCheck[] 배열을 반환한다. 하나의 EvidenceCheck = 하나의
// requiredFacts 키워드에 대응하는 최소 판정 단위. topic-engine.ts는 이 배열을 받아
// §8 "조건 검증(충족 근거 ≥2, confidence 가드레일)"을 적용한다.
import {
  countTenGodGroup,
  TEN_GOD_GROUPS,
  resolveTenGodElements,
  splitGanZhiKr,
  isChongPair,
} from "./bazi-elements";
import type { SajuV3Facts } from "./saju-facts-types";

export interface EvidenceCheck {
  /** evidence_fact_keys[] 응답 계약에 그대로 노출되는 식별자(영문 snake_case). */
  factKey: string;
  satisfied: boolean;
  /** 0~1. §8 confidence 가드레일 평균 계산에 사용. */
  confidence: number;
  /** 내부 디버그/감사용 설명(사용자 노출 금지 — 7장 원칙). */
  note: string;
}

export type TopicEvidenceEvaluator = (facts: SajuV3Facts) => EvidenceCheck[];

/** 십신 7슬롯 중 특정 그룹 비율이 임계값 이상인지. TALENT_001의 "편중(≥35%)" 기준을
 * 다른 "과다/비중" 조건에도 동일하게 적용한다(지시서가 유일하게 숫자로 준 편중 기준). */
const DOMINANCE_THRESHOLD = 0.35;

function laterHalf<T>(arr: T[] | undefined): T[] {
  if (!arr || arr.length === 0) return [];
  const half = Math.ceil(arr.length / 2);
  return arr.slice(half);
}

function relationsContainChar(facts: SajuV3Facts, ch: string | undefined): boolean {
  if (!ch) return false;
  const all = [
    ...(facts.relations?.liuhe ?? []),
    ...(facts.relations?.sanhe ?? []),
    ...(facts.relations?.sanhe_half ?? []),
    ...(facts.relations?.chong ?? []),
    ...(facts.relations?.xing ?? []),
    ...(facts.relations?.xing_self ?? []),
    ...(facts.relations?.po ?? []),
    ...(facts.relations?.hai ?? []),
    ...(facts.relations?.yuanjin ?? []),
  ];
  return all.some((s) => s.includes(ch));
}

function sinsalIncludes(facts: SajuV3Facts, keyword: string): boolean {
  return (facts.sinsal ?? []).some((s) => s.includes(keyword));
}

/** 배우자성(配偶者星) — 전통 사주 관례: 남성=정재, 여성=정관. gender는 facts.input에서 가져온다. */
function spouseStarGroup(facts: SajuV3Facts): string[] {
  const gender = (facts.input as Record<string, unknown> | undefined)?.gender;
  const isFemale = gender === "female" || gender === "F" || gender === "여";
  return isFemale ? ["정관"] : ["정재"];
}

function latestLuckElementMatches(facts: SajuV3Facts, targetElement: string | undefined): boolean {
  if (!targetElement) return false;
  const later = laterHalf(facts.luck_pillars);
  return later.some((lp) => {
    const parsed = splitGanZhiKr(lp.gan_zhi_kr);
    return parsed?.ganElement === targetElement || parsed?.zhiElement === targetElement;
  });
}

// ──────────────────────────────────────────────────────────────
// 폴백
// ──────────────────────────────────────────────────────────────
const evalLIFE_000: TopicEvidenceEvaluator = (facts) => [
  {
    factKey: "pillars_present",
    satisfied: !!facts.pillars,
    confidence: facts.pillars ? 1 : 0,
    note: "사주 명식 존재 — 폴백은 항상 활성(지시서 §8 폴백 보장)",
  },
  {
    factKey: "yongshin_present",
    satisfied: !!facts.yongshin,
    confidence: facts.yongshin ? 1 : 0,
    note: "용신 데이터 존재",
  },
];

// ──────────────────────────────────────────────────────────────
// MONEY
// ──────────────────────────────────────────────────────────────
const evalMONEY_001: TopicEvidenceEvaluator = (facts) => {
  const wealth = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["재성"]);
  const elements = resolveTenGodElements(facts.day_master?.element);
  const wealthElement = elements["재성"];
  const yongOrHee = [facts.yongshin?.yong, facts.yongshin?.hee].filter(Boolean);
  const matchesYong = !!wealthElement && yongOrHee.includes(wealthElement);
  return [
    { factKey: "wealth_star_type", satisfied: wealth.count > 0, confidence: wealth.count > 0 ? 0.8 : 0, note: "편재/정재 존재 여부" },
    { factKey: "wealth_element", satisfied: !!wealthElement, confidence: wealthElement ? 0.7 : 0, note: "일간 기준 재성 오행 역산" },
    { factKey: "wealth_yongshin_relation", satisfied: matchesYong, confidence: matchesYong ? 0.8 : 0.4, note: "재성 오행-용신/희신 일치 여부" },
  ];
};

const evalMONEY_002: TopicEvidenceEvaluator = (facts) => {
  const wealth = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["재성"]);
  const peer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["비겁"]);
  const output = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["식상"]);
  return [
    { factKey: "wealth_ratio", satisfied: wealth.total > 0, confidence: wealth.total > 0 ? 0.7 : 0, note: "편재/정재 비중" },
    { factKey: "peer_star", satisfied: peer.count > 0, confidence: peer.count > 0 ? 0.6 : 0.3, note: "겁재 존재" },
    { factKey: "output_star", satisfied: output.count > 0, confidence: output.count > 0 ? 0.6 : 0.3, note: "식상 존재" },
  ];
};

const evalMONEY_003: TopicEvidenceEvaluator = (facts) => {
  const peer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["비겁"]);
  const peerExcess = peer.ratio >= DOMINANCE_THRESHOLD;
  const hasAdjacentClash =
    (facts.relations?.chong?.length ?? 0) > 0 || (facts.relations?.hai?.length ?? 0) > 0;
  return [
    { factKey: "peer_excess", satisfied: peerExcess, confidence: peerExcess ? 0.75 : 0.3, note: `비겁 비율 ${peer.ratio.toFixed(2)} (기준 ${DOMINANCE_THRESHOLD})` },
    { factKey: "wealth_adjacent_clash", satisfied: hasAdjacentClash, confidence: hasAdjacentClash ? 0.6 : 0.3, note: "재성 인접 충·해(특이 조건)" },
  ];
};

const evalMONEY_004: TopicEvidenceEvaluator = (facts) => {
  const elements = resolveTenGodElements(facts.day_master?.element);
  const wealthElement = elements["재성"];
  const inflow = latestLuckElementMatches(facts, wealthElement);
  const yongOrHee = [facts.yongshin?.yong, facts.yongshin?.hee].filter(Boolean);
  const matchesYong = !!wealthElement && yongOrHee.includes(wealthElement);
  const currentParsed = splitGanZhiKr(facts.current_luck?.gan_zhi_kr);
  const currentMatches =
    !!wealthElement && (currentParsed?.ganElement === wealthElement || currentParsed?.zhiElement === wealthElement);
  return [
    { factKey: "luck_wealth_inflow", satisfied: inflow || currentMatches, confidence: inflow || currentMatches ? 0.8 : 0.3, note: "대운에 재성 오행 유입(후반 또는 현재)" },
    { factKey: "wealth_yongshin_relation", satisfied: matchesYong, confidence: matchesYong ? 0.7 : 0.4, note: "재성-용신 관계" },
    { factKey: "current_luck_present", satisfied: !!facts.current_luck, confidence: facts.current_luck ? 0.6 : 0, note: "세운(현재 대운) 데이터 존재" },
  ];
};

const evalMONEY_005: TopicEvidenceEvaluator = (facts) => {
  const partial = countTenGodGroup(facts.ten_gods, ["편재"]);
  const officer = countTenGodGroup(facts.ten_gods, ["정관"]);
  return [
    { factKey: "partial_wealth_vs_officer", satisfied: partial.count > 0 || officer.count > 0, confidence: partial.count > 0 && officer.count > 0 ? 0.7 : 0.4, note: "편재 vs 정관 비중" },
    { factKey: "day_master_strength", satisfied: !!facts.day_master_strength, confidence: facts.day_master_strength ? 0.6 : 0, note: "격국 근사치(신강/신약)" },
  ];
};

const evalMONEY_006: TopicEvidenceEvaluator = evalMONEY_002;

// ──────────────────────────────────────────────────────────────
// TALENT
// ──────────────────────────────────────────────────────────────
function maxTenGodGroupRatio(facts: SajuV3Facts): { groupName: string; ratio: number } {
  let best = { groupName: "", ratio: 0 };
  for (const [groupName, names] of Object.entries(TEN_GOD_GROUPS)) {
    const { ratio } = countTenGodGroup(facts.ten_gods, names);
    if (ratio > best.ratio) best = { groupName, ratio };
  }
  return best;
}

const evalTALENT_001: TopicEvidenceEvaluator = (facts) => {
  const { groupName, ratio } = maxTenGodGroupRatio(facts);
  const dominant = ratio >= DOMINANCE_THRESHOLD;
  return [
    { factKey: "ten_god_dominance", satisfied: dominant, confidence: dominant ? 0.8 : 0.3, note: `최대 십신그룹 ${groupName} 비율 ${ratio.toFixed(2)}` },
    { factKey: "day_master_strength_score", satisfied: typeof facts.day_master_strength_score === "number", confidence: typeof facts.day_master_strength_score === "number" ? 0.6 : 0, note: "강약 점수 존재" },
  ];
};

const evalTALENT_002: TopicEvidenceEvaluator = (facts) => {
  const peer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["비겁"]);
  const officer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["관성"]);
  const output = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["식상"]);
  const combinedRatio = officer.ratio + output.ratio;
  // [버그 수정 — STEP6 실제 해석 테스트] note에 소수점(`.toFixed(2)`)이 들어가면
  // interpret-qa-check.ts의 checkRepetition()이 "."를 문장 구분자로 오인해 note를
  // 둘로 쪼개고("비겁 0" + "43 vs 관성+식상 0" + "71"), 그 중간 조각이 fallback
  // 템플릿의 여러 블록(①③)에 동일하게 삽입되어 REPEATED_SENTENCE로 오탐되는 실제
  // 장애가 있었다(TALENT_002 detail 503). 소수점 대신 마침표 없는 퍼센트 정수로 표기.
  return [
    { factKey: "peer_vs_officer_output", satisfied: peer.total > 0, confidence: peer.total > 0 ? 0.7 : 0, note: `비겁 ${Math.round(peer.ratio * 100)}% vs 관성+식상 ${Math.round(combinedRatio * 100)}%` },
  ];
};

const evalTALENT_003: TopicEvidenceEvaluator = (facts) => {
  const officer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["관성"]);
  return [
    { factKey: "officer_star_state", satisfied: officer.count > 0, confidence: officer.count > 0 ? 0.7 : 0.3, note: "관성 상태" },
    { factKey: "day_master_strength", satisfied: !!facts.day_master_strength, confidence: facts.day_master_strength ? 0.6 : 0, note: "강약" },
  ];
};

const evalTALENT_004: TopicEvidenceEvaluator = (facts) => {
  const yong = facts.yongshin?.yong;
  const laterHasYong = latestLuckElementMatches(facts, yong);
  return [
    { factKey: "later_luck_yongshin", satisfied: laterHasYong, confidence: laterHasYong ? 0.8 : 0.3, note: "용신 오행이 후반 대운에 등장(특이 조건)" },
  ];
};

const evalTALENT_005: TopicEvidenceEvaluator = (facts) => {
  const officerElement = resolveTenGodElements(facts.day_master?.element)["관성"];
  const laterHasOfficer = latestLuckElementMatches(facts, officerElement);
  const dz = facts.pillars?.day?.kr?.[1];
  const currentZhi = facts.current_luck?.gan_zhi_kr?.[1];
  const clash = isChongPair(dz, currentZhi);
  return [
    { factKey: "luck_officer_shift", satisfied: laterHasOfficer, confidence: laterHasOfficer ? 0.7 : 0.3, note: "대운 관성 전환" },
    { factKey: "day_zhi_chong", satisfied: clash, confidence: clash ? 0.7 : 0.3, note: "일지 충" },
  ];
};

// ──────────────────────────────────────────────────────────────
// PERSONALITY
// ──────────────────────────────────────────────────────────────
const evalPERSONALITY_001: TopicEvidenceEvaluator = (facts) => [
  { factKey: "ten_god_distribution", satisfied: !!facts.ten_gods, confidence: facts.ten_gods ? 0.8 : 0, note: "십신 5그룹 분포" },
  { factKey: "day_master", satisfied: !!facts.day_master, confidence: facts.day_master ? 0.8 : 0, note: "일간" },
  { factKey: "five_elements", satisfied: !!facts.five_elements_weighted, confidence: facts.five_elements_weighted ? 0.8 : 0, note: "오행(A02 근거)" },
];

// ──────────────────────────────────────────────────────────────
// RELATION
// ──────────────────────────────────────────────────────────────
const evalRELATION_001: TopicEvidenceEvaluator = (facts) => {
  const harmonyCount = (facts.relations?.liuhe?.length ?? 0) + (facts.relations?.sanhe?.length ?? 0) + (facts.relations?.sanhe_half?.length ?? 0);
  const resource = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["인성"]);
  const peer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["비겁"]);
  return [
    { factKey: "harmony_count", satisfied: harmonyCount > 0, confidence: harmonyCount > 0 ? 0.7 : 0.3, note: `합 개수 ${harmonyCount}` },
    { factKey: "resource_star", satisfied: resource.count > 0, confidence: resource.count > 0 ? 0.6 : 0.3, note: "인성" },
    { factKey: "peer_star", satisfied: peer.count > 0, confidence: peer.count > 0 ? 0.6 : 0.3, note: "비겁" },
  ];
};

const evalRELATION_002: TopicEvidenceEvaluator = (facts) => {
  const hasNobleman = sinsalIncludes(facts, "貴人");
  return [
    { factKey: "nobleman_sinsal", satisfied: hasNobleman, confidence: hasNobleman ? 0.85 : 0.2, note: "귀인계 신살(天乙·天德·月德 등)" },
    { factKey: "yongshin_element", satisfied: !!facts.yongshin?.yong, confidence: facts.yongshin?.yong ? 0.6 : 0, note: "용신 오행" },
  ];
};

const evalRELATION_003: TopicEvidenceEvaluator = evalMONEY_003;

const evalRELATION_004: TopicEvidenceEvaluator = (facts) => {
  const harmonyCount = (facts.relations?.liuhe?.length ?? 0) + (facts.relations?.sanhe?.length ?? 0);
  const chongCount = facts.relations?.chong?.length ?? 0;
  const output = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["식상"]);
  return [
    { factKey: "harmony_chong_ratio", satisfied: harmonyCount + chongCount > 0, confidence: harmonyCount + chongCount > 0 ? 0.65 : 0.3, note: `합/충 비율(합${harmonyCount}/충${chongCount})` },
    { factKey: "output_star", satisfied: output.count > 0, confidence: output.count > 0 ? 0.6 : 0.3, note: "식상" },
  ];
};

const evalRELATION_005: TopicEvidenceEvaluator = (facts) => {
  const resourceSkewed = countTenGodGroup(facts.ten_gods, ["편인"]);
  const dayZhiHiddenStems = (facts.zhi_qigan?.day?.length ?? 0) > 0;
  return [
    { factKey: "indirect_resource", satisfied: resourceSkewed.count > 0, confidence: resourceSkewed.count > 0 ? 0.7 : 0.3, note: "편인" },
    { factKey: "day_zhi_hidden_stems", satisfied: dayZhiHiddenStems, confidence: dayZhiHiddenStems ? 0.6 : 0, note: "일지 지장간" },
  ];
};

// ──────────────────────────────────────────────────────────────
// LOVE
// ──────────────────────────────────────────────────────────────
const evalLOVE_001: TopicEvidenceEvaluator = (facts) => {
  const output = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["식상"]);
  const officer = countTenGodGroup(facts.ten_gods, TEN_GOD_GROUPS["관성"]);
  // [버그 수정 — STEP6 실제 해석 테스트, TALENT_002와 동일 원인] note의 소수점이
  // checkRepetition()의 "." 문장 분리기를 오동작시켜 fallback 다중 블록에 동일 조각이
  // 반복 삽입되고 REPEATED_SENTENCE로 오탐되어 LOVE_001 detail이 503이 나던 실제 장애를
  // 수정(퍼센트 정수 표기로 소수점 제거, 다른 Topic/로직은 변경하지 않음).
  return [
    { factKey: "output_vs_officer", satisfied: output.total > 0, confidence: output.total > 0 ? 0.65 : 0, note: `식상 ${Math.round(output.ratio * 100)}% vs 관성 ${Math.round(officer.ratio * 100)}%` },
    { factKey: "day_pillar_present", satisfied: !!facts.pillars?.day, confidence: facts.pillars?.day ? 0.6 : 0, note: "일지" },
  ];
};

const evalLOVE_002: TopicEvidenceEvaluator = (facts) => {
  const dz = facts.pillars?.day?.kr?.[1];
  const relatesDayZhi = relationsContainChar(facts, dz);
  const biasedStar = countTenGodGroup(facts.ten_gods, ["편재", "편관", "편인"]);
  const hiddenStems = (facts.zhi_qigan?.day?.length ?? 0) > 0;
  return [
    { factKey: "day_zhi_relation", satisfied: relatesDayZhi, confidence: relatesDayZhi ? 0.7 : 0.3, note: "일지 합·충" },
    { factKey: "biased_ten_god", satisfied: biasedStar.count > 0, confidence: biasedStar.count > 0 ? 0.6 : 0.3, note: "편성 십신" },
    { factKey: "hidden_stems", satisfied: hiddenStems, confidence: hiddenStems ? 0.6 : 0, note: "지장간" },
  ];
};

const evalLOVE_003: TopicEvidenceEvaluator = (facts) => {
  const krZhi = facts.pillars?.day?.kr?.[1];
  const zhiElementMap: Record<string, string> = {
    자: "수", 축: "토", 인: "목", 묘: "목", 진: "토", 사: "화", 오: "화", 미: "토", 신: "금", 유: "금", 술: "토", 해: "수",
  };
  const dayZhiElement = krZhi ? zhiElementMap[krZhi] : undefined;
  const yongOrHee = [facts.yongshin?.yong, facts.yongshin?.hee].filter(Boolean);
  const matches = !!dayZhiElement && yongOrHee.includes(dayZhiElement);
  return [
    // [confidence 가드레일 — 지시서 §7 LOVE_003 비고] 다른 주제보다 낮은 confidence를
    // 의도적으로 부여해, "충족 근거는 있으나 확신도가 낮은" 사례를 가드레일이 실제로
    // 걸러내는지 검증할 수 있게 한다(§8 "조건 검증... confidence 가드레일" 구현 대상).
    { factKey: "day_zhi_yongshin_match", satisfied: matches, confidence: matches ? 0.55 : 0.3, note: "일지 오행-용신/희신 일치(가드레일 적용 대상)" },
  ];
};

const evalLOVE_004: TopicEvidenceEvaluator = (facts) => {
  const krZhi = facts.pillars?.day?.kr?.[1];
  const zhiElementMap: Record<string, string> = {
    자: "수", 축: "토", 인: "목", 묘: "목", 진: "토", 사: "화", 오: "화", 미: "토", 신: "금", 유: "금", 술: "토", 해: "수",
  };
  const dayZhiElement = krZhi ? zhiElementMap[krZhi] : undefined;
  const yongOrHee = [facts.yongshin?.yong, facts.yongshin?.hee].filter(Boolean);
  const exactMatch = !!dayZhiElement && yongOrHee.includes(dayZhiElement);
  // [특이 조건 — 아니면 미노출] 지시서가 "특이 조건"이라고 명시한 유일한 LOVE 주제.
  // 다른 주제처럼 "증거 2개 이상이면 통과"가 아니라, 이 1개 조건 자체가 하드 게이트다.
  return [
    { factKey: "day_zhi_equals_yongshin", satisfied: exactMatch, confidence: exactMatch ? 0.9 : 0, note: "일지 오행=용신/희신(특이 조건, 미충족시 완전 미노출)" },
  ];
};

const evalLOVE_005: TopicEvidenceEvaluator = (facts) => {
  const spouseGroup = spouseStarGroup(facts);
  const spouseElement = resolveTenGodElements(facts.day_master?.element)[spouseGroup[0] === "정관" ? "관성" : "재성"];
  const laterInflow = latestLuckElementMatches(facts, spouseElement);
  return [
    { factKey: "spouse_star_later_luck", satisfied: laterInflow, confidence: laterInflow ? 0.8 : 0.3, note: "배우자성 후반 대운 유입(특이 조건)" },
  ];
};

const evalLOVE_006: TopicEvidenceEvaluator = (facts) => {
  const spouseGroup = spouseStarGroup(facts);
  const spouseElement = resolveTenGodElements(facts.day_master?.element)[spouseGroup[0] === "정관" ? "관성" : "재성"];
  const currentParsed = splitGanZhiKr(facts.current_luck?.gan_zhi_kr);
  const currentMatches = !!spouseElement && (currentParsed?.ganElement === spouseElement || currentParsed?.zhiElement === spouseElement);
  const hasDohwa = sinsalIncludes(facts, "桃花");
  return [
    { factKey: "spouse_star_current_luck", satisfied: currentMatches, confidence: currentMatches ? 0.75 : 0.3, note: "배우자성 대운" },
    { factKey: "dohwa_sinsal", satisfied: hasDohwa, confidence: hasDohwa ? 0.7 : 0.2, note: "도화" },
  ];
};

// ──────────────────────────────────────────────────────────────
// LIFE (시기형 다수)
// ──────────────────────────────────────────────────────────────
const RISING_TWELVE_STAGES = new Set(["장생", "관대", "건록", "제왕"]);

const evalLIFE_001: TopicEvidenceEvaluator = (facts) => {
  const dz = facts.pillars?.day?.kr?.[1];
  const currentZhi = facts.current_luck?.gan_zhi_kr?.[1];
  const clash = isChongPair(dz, currentZhi);
  return [
    { factKey: "luck_transition_point", satisfied: !!facts.current_luck, confidence: facts.current_luck ? 0.6 : 0, note: "대운 전환점(A10 근거)" },
    { factKey: "luck_zhi_chong", satisfied: clash, confidence: clash ? 0.8 : 0.3, note: "대운 지지 충" },
  ];
};

const evalLIFE_002: TopicEvidenceEvaluator = (facts) => {
  const yong = facts.yongshin?.yong;
  const laterHasYong = latestLuckElementMatches(facts, yong);
  const stages = [facts.twelve_stages?.day, facts.twelve_stages?.hour].filter(Boolean) as string[];
  const rising = stages.some((s) => RISING_TWELVE_STAGES.has(s));
  return [
    { factKey: "later_luck_yongshin", satisfied: laterHasYong, confidence: laterHasYong ? 0.8 : 0.3, note: "후반 대운 용신" },
    { factKey: "twelve_stage_rising", satisfied: rising, confidence: rising ? 0.6 : 0.3, note: "십이운성 상승" },
  ];
};

const evalLIFE_003: TopicEvidenceEvaluator = (facts) => {
  const yong = facts.yongshin?.yong;
  const laterHasYong = latestLuckElementMatches(facts, yong);
  return [
    { factKey: "hour_pillar_present", satisfied: !!facts.pillars?.hour, confidence: facts.pillars?.hour ? 0.6 : 0, note: "시주" },
    { factKey: "later_luck_yongshin", satisfied: laterHasYong, confidence: laterHasYong ? 0.8 : 0.3, note: "후반 대운 용신" },
  ];
};

const evalLIFE_004: TopicEvidenceEvaluator = (facts) => {
  const yong = facts.yongshin?.yong;
  const currentParsed = splitGanZhiKr(facts.current_luck?.gan_zhi_kr);
  const currentMatches = !!yong && (currentParsed?.ganElement === yong || currentParsed?.zhiElement === yong);
  return [
    { factKey: "current_luck_vs_yongshin", satisfied: currentMatches, confidence: currentMatches ? 0.8 : 0.3, note: "현재 대운+세운 vs 용신(B01/B10 근거)" },
  ];
};

const evalLIFE_006: TopicEvidenceEvaluator = (facts) => {
  const yong = facts.yongshin?.yong;
  const anyPeak = (facts.luck_pillars ?? []).some((lp) => {
    const parsed = splitGanZhiKr(lp.gan_zhi_kr);
    return !!yong && (parsed?.ganElement === yong || parsed?.zhiElement === yong);
  });
  return [
    { factKey: "luck_array_peak", satisfied: anyPeak, confidence: anyPeak ? 0.75 : 0.3, note: "대운 배열 최고점(B08 근거)" },
  ];
};

/** topicId → evaluator 매핑. topic-engine.ts가 이 맵으로 조건 검증을 수행한다. */
export const TOPIC_EVIDENCE_EVALUATORS: Record<string, TopicEvidenceEvaluator> = {
  LIFE_000: evalLIFE_000,
  MONEY_001: evalMONEY_001,
  MONEY_002: evalMONEY_002,
  MONEY_003: evalMONEY_003,
  MONEY_004: evalMONEY_004,
  MONEY_005: evalMONEY_005,
  MONEY_006: evalMONEY_006,
  TALENT_001: evalTALENT_001,
  TALENT_002: evalTALENT_002,
  TALENT_003: evalTALENT_003,
  TALENT_004: evalTALENT_004,
  TALENT_005: evalTALENT_005,
  PERSONALITY_001: evalPERSONALITY_001,
  RELATION_001: evalRELATION_001,
  RELATION_002: evalRELATION_002,
  RELATION_003: evalRELATION_003,
  RELATION_004: evalRELATION_004,
  RELATION_005: evalRELATION_005,
  LOVE_001: evalLOVE_001,
  LOVE_002: evalLOVE_002,
  LOVE_003: evalLOVE_003,
  LOVE_004: evalLOVE_004,
  LOVE_005: evalLOVE_005,
  LOVE_006: evalLOVE_006,
  LIFE_001: evalLIFE_001,
  LIFE_002: evalLIFE_002,
  LIFE_003: evalLIFE_003,
  LIFE_004: evalLIFE_004,
  LIFE_006: evalLIFE_006,
};
