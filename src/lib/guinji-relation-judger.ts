// 귀인지도(Guinji Map) 관계 판정 엔진 — RelationJudger (서버 순수 함수).
//
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §7] "관계 판정 로직" 대응.
// [사주 계산 아키텍처 - B안 확정] 정통사주 만세력 실계산(60갑자·오행·십신·
// 신살)은 Flutter `ManseryeokCoreEngine`/`Phase2AnalysisEngine`/
// `SinsalEngine`에서만 수행한다. 이 파일은 클라이언트가 이미 계산해 보낸
// 사주 JSON(`GuinjiSajuInput`)을 입력받아 "두 사람의 사주를 대조해 관계
// 유형·케미 점수를 정하는" 판정 로직만 서버에 순수 함수로 구현한다 —
// 사주 원국 자체를 재계산하지 않는다(§4 "정통사주 만세력은 클라이언트
// 단일 소스" 원칙과 동일 경계).
//
// [M1 확정안] 5유형 대입 우선순위: 합 > 인성 > 관성 > 식상 > 비겁.
// [M2 확정안] 케미 점수 가중치: 오행 50 + 신살 30 + 합 20 (합 100).
//
// [보완 결정 - 이번 Phase] 개발계획서 §7의 10십성 중 "재성(편재/정재,
// 내가 극하는 관계)"은 5유형 어디에도 명시적으로 매핑되어 있지 않다(귀인/
// 오른팔/인연/살림꾼/호랑이선생은 인성·비겁·합·식상·관성만 언급). 재성은
// "내가 다루고 관리하는 자원" 성격이 살림꾼(養, 養: 내가 챙기고 이끌어줌)의
// 취지와 가장 가깝다고 판단해 살림꾼으로 폴백 매핑한다 — 이 결정은
// Phase 완료 보고 시 사용자에게 별도로 투명하게 공유한다.

/** 천간 → (오행, 음양). saju_engine.dart의 ganElement와 동일한 고정표. */
const GAN_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  甲: { el: "목", yy: "양" },
  乙: { el: "목", yy: "음" },
  丙: { el: "화", yy: "양" },
  丁: { el: "화", yy: "음" },
  戊: { el: "토", yy: "양" },
  己: { el: "토", yy: "음" },
  庚: { el: "금", yy: "양" },
  辛: { el: "금", yy: "음" },
  壬: { el: "수", yy: "양" },
  癸: { el: "수", yy: "음" },
};

/** 지지 → (오행, 음양). saju_engine.dart의 zhiElement와 동일한 고정표(본기 기준). */
const ZHI_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  子: { el: "수", yy: "양" },
  丑: { el: "토", yy: "음" },
  寅: { el: "목", yy: "양" },
  卯: { el: "목", yy: "음" },
  辰: { el: "토", yy: "양" },
  巳: { el: "화", yy: "음" },
  午: { el: "화", yy: "양" },
  未: { el: "토", yy: "음" },
  申: { el: "금", yy: "양" },
  酉: { el: "금", yy: "음" },
  戌: { el: "토", yy: "양" },
  亥: { el: "수", yy: "음" },
};

/** 오행 상생(내가 생하는 것). */
const SHENG: Record<string, string> = { 목: "화", 화: "토", 토: "금", 금: "수", 수: "목" };
/** 오행 상극(내가 극하는 것). */
const KE: Record<string, string> = { 목: "토", 토: "수", 수: "화", 화: "금", 금: "목" };

/**
 * 일간(dayGan) 기준 상대 글자(천간 또는 지지)의 십신을 계산한다.
 * `saju_engine.dart`의 `getTenGod()`/`tenGodsTable`을 TypeScript로 그대로
 * 이식한 것 — 새로운 명리 판정 규칙이 아니라 이미 검증된 로직의 재구현.
 */
const TEN_GODS_TABLE: Record<string, string> = {
  "same:true": "비견",
  "same:false": "겁재",
  "生out:true": "식신",
  "生out:false": "상관",
  "克out:true": "편재",
  "克out:false": "정재",
  "克in:true": "편관",
  "克in:false": "정관",
  "生in:true": "편인",
  "生in:false": "정인",
};

function elementOf(char: string): { el: string; yy: "양" | "음" } | null {
  return GAN_ELEMENT[char] ?? ZHI_ELEMENT[char] ?? null;
}

function getTenGod(dayGan: string, target: string): string | null {
  const day = GAN_ELEMENT[dayGan];
  const tgt = elementOf(target);
  if (!day || !tgt) return null;
  const sameYy = day.yy === tgt.yy;
  let rel: string;
  if (day.el === tgt.el) rel = "same";
  else if (SHENG[day.el] === tgt.el) rel = "生out";
  else if (KE[day.el] === tgt.el) rel = "克out";
  else if (KE[tgt.el] === day.el) rel = "克in";
  else if (SHENG[tgt.el] === day.el) rel = "生in";
  else rel = "same";
  return TEN_GODS_TABLE[`${rel}:${sameYy}`] ?? null;
}

/** 천간합(天干合, 五合) — 甲己合土/乙庚合金/丙辛合水/丁壬合木/戊癸合火. */
const CHEONGAN_HAP: Array<[string, string]> = [
  ["甲", "己"],
  ["乙", "庚"],
  ["丙", "辛"],
  ["丁", "壬"],
  ["戊", "癸"],
];

/** 지지육합(六合) — 子丑/寅亥/卯戌/辰酉/巳申/午未. */
const JIJI_YUKHAP: Array<[string, string]> = [
  ["子", "丑"],
  ["寅", "亥"],
  ["卯", "戌"],
  ["辰", "酉"],
  ["巳", "申"],
  ["午", "未"],
];

function isPair(a: string, b: string, table: Array<[string, string]>): boolean {
  return table.some(([x, y]) => (x === a && y === b) || (x === b && y === a));
}

/**
 * 클라이언트(`ManseryeokCoreEngine`)가 계산해 전달하는 사주 JSON 계약.
 * [Phase 0 확정 — API 계약] Flutter 앱이 이 형태로 `sajuParsed`를 구성해
 * 서버에 전송한다. 서버는 이 값을 재계산하지 않고 그대로 신뢰한다(B안).
 */
export interface GuinjiSajuInput {
  /** 일간 한자(예: '甲') — 십성 판정 기준. */
  dayStemHanja: string;
  /** 년/월/일/시 천간 한자 4글자(합 판정용). */
  stems: { year: string; month: string; day: string; hour: string };
  /** 년/월/일/시 지지 한자 4글자(육합 판정용). */
  branches: { year: string; month: string; day: string; hour: string };
  /** 오행 카운트(천간+지지 단순 합산, 키: 목/화/토/금/수). */
  fiveElementsCount: Record<string, number>;
  /**
   * 신살 ID 목록(`SinsalEntry.id`, 예: '天乙貴人'). RelationJudger는 이 중
   * 천을귀인만 귀인(貴) 판정 가중치에 사용한다(M10: 신살엔진은 이미 30여종
   * 존재하나, 문서 §7이 명시한 "천을/천덕/월덕" 중 현재 엔진에 실존하는
   * 것은 천을귀인뿐 — 천덕귀인/월덕귀인은 sinsal_engine.dart 미구현).
   */
  sinsalIds: string[];
}

export function isValidGuinjiSajuInput(v: unknown): v is GuinjiSajuInput {
  if (!v || typeof v !== "object") return false;
  const o = v as Record<string, unknown>;
  if (typeof o.dayStemHanja !== "string") return false;
  const stems = o.stems as Record<string, unknown> | undefined;
  const branches = o.branches as Record<string, unknown> | undefined;
  if (!stems || !branches) return false;
  for (const k of ["year", "month", "day", "hour"]) {
    if (typeof stems[k] !== "string" || typeof branches[k] !== "string") return false;
  }
  if (!o.fiveElementsCount || typeof o.fiveElementsCount !== "object") return false;
  if (!Array.isArray(o.sinsalIds)) return false;
  return true;
}

export type GuinjiRelationType = "guin" | "oreunpal" | "inyeon" | "salrim" | "horang";

export interface GuinjiJudgeResult {
  relationType: GuinjiRelationType;
  chemistryScore: number;
  ohaengEvidence: {
    mine: Record<string, number>;
    other: Record<string, number>;
    reason: string;
  };
}

const OHAENG_ORDER = ["목", "화", "토", "금", "수"];

function normalizeFiveElements(raw: Record<string, number>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k of OHAENG_ORDER) out[k] = Math.max(0, Math.trunc(raw[k] ?? 0));
  return out;
}

/**
 * [RelationJudger 핵심] owner(나) 기준으로 member(상대)와의 관계를 판정한다.
 *
 * @param mine owner의 사주(나).
 * @param other member의 사주(상대) — 3기둥(생시 미입력)인 경우 hour는
 *   임의값이 아니라 호출부에서 day 값 등으로 채워 들어올 수 있으므로, 이
 *   함수는 hour 기둥의 합 판정에는 관여하지 않고 년/월/일 지지만 육합
 *   판정에 사용한다(생시 미입력 안전성 — M1 판정에서 시주는 참고하지
 *   않는다. 문서 §7 "생시 미입력 시 3기둥 기반 산출" 원칙 반영).
 */
export function judgeGuinjiRelation(
  mine: GuinjiSajuInput,
  other: GuinjiSajuInput
): GuinjiJudgeResult {
  const mineDayGan = mine.dayStemHanja;
  const otherDayGan = other.dayStemHanja;

  // ── 1) 합(천간합/지지육합) 판정 — 일간끼리 + 년/월/일지끼리 대조.
  //    (시지는 생시 미입력 안전성을 위해 판정에서 제외한다.)
  const hasCheonganHap = isPair(mineDayGan, otherDayGan, CHEONGAN_HAP);
  const mineBranches = [mine.branches.year, mine.branches.month, mine.branches.day];
  const otherBranches = [other.branches.year, other.branches.month, other.branches.day];
  const hasJijiHap = mineBranches.some((mb) => otherBranches.some((ob) => isPair(mb, ob, JIJI_YUKHAP)));
  const hasHap = hasCheonganHap || hasJijiHap;

  // ── 2) other 일간 → my 일간 기준 십성 판정.
  const tenGod = getTenGod(mineDayGan, otherDayGan);
  const hasCheoneulGwiin = other.sinsalIds.includes("天乙貴人");

  // ── 3) M1 대입표(우선순위: 합 > 인성 > 관성 > 식상 > 비겁) ──
  let relationType: GuinjiRelationType;
  let reason: string;

  if (hasHap) {
    relationType = "inyeon";
    reason = hasCheonganHap ? "천간합 · 서로 끌리는 사이" : "지지육합 · 자연스러운 인연";
  } else if (tenGod === "정인" || tenGod === "편인" || hasCheoneulGwiin) {
    relationType = "guin";
    reason = hasCheoneulGwiin
      ? "천을귀인 · 인성 작용"
      : tenGod === "정인"
        ? "정인 · 나를 살리는 기운"
        : "편인 · 독특한 조력";
  } else if (tenGod === "정관" || tenGod === "편관") {
    relationType = "horang";
    reason = tenGod === "정관" ? "정관 · 바른 성장 자극" : "편관 · 도전과 긴장";
  } else if (tenGod === "식신" || tenGod === "상관") {
    relationType = "salrim";
    reason = tenGod === "식신" ? "식신 · 내가 살피고 돌봄" : "상관 · 내가 이끄는 표현";
  } else if (tenGod === "비견" || tenGod === "겁재") {
    relationType = "oreunpal";
    reason = tenGod === "비견" ? "비견 · 같은 오행, 협력" : "겁재 · 같은 기운, 경쟁과 협력";
  } else if (tenGod === "편재" || tenGod === "정재") {
    // [보완 결정] 재성은 5유형 대입표에 명시가 없어 "내가 다루는 자원"
    // 취지가 가까운 살림꾼으로 폴백한다.
    relationType = "salrim";
    reason = tenGod === "정재" ? "정재 · 내가 다루는 안정된 자원" : "편재 · 내가 다루는 유동적 자원";
  } else {
    // 이론상 도달하지 않음(십성은 위 10종이 전부) — 방어적 폴백.
    relationType = "oreunpal";
    reason = "같은 기운";
  }

  // ── 4) 케미 점수(M2: 오행 50 + 신살 30 + 합 20) ──
  const mineEl = GAN_ELEMENT[mineDayGan]?.el;
  const otherEl = GAN_ELEMENT[otherDayGan]?.el;
  let ohaengScore = 30; // 기본값(관계 불명 시에도 중립 점수 부여)
  if (mineEl && otherEl) {
    if (mineEl === otherEl) ohaengScore = 35; // 비겁: 같은 오행
    else if (SHENG[mineEl] === otherEl) ohaengScore = 45; // 내가 상대를 생(식상)
    else if (SHENG[otherEl] === mineEl) ohaengScore = 50; // 상대가 나를 생(인성) — 귀인 취지 최고점
    else if (KE[mineEl] === otherEl) ohaengScore = 25; // 내가 상대를 극(재성)
    else if (KE[otherEl] === mineEl) ohaengScore = 15; // 상대가 나를 극(관성)
  }
  const sinsalScore = hasCheoneulGwiin ? 30 : 0;
  const hapScore = hasHap ? 20 : 0;
  const chemistryScore = Math.max(0, Math.min(100, ohaengScore + sinsalScore + hapScore));

  return {
    relationType,
    chemistryScore,
    ohaengEvidence: {
      mine: normalizeFiveElements(mine.fiveElementsCount),
      other: normalizeFiveElements(other.fiveElementsCount),
      reason,
    },
  };
}
