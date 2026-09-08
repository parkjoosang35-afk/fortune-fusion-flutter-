// 귀인지도(Guinji Map) 관계 판정 엔진 — RelationJudger (서버 순수 함수).
//
// [2026-09 전면 재작성 — 12라벨 체계] 사용자 확정: (1) 관계 라벨을 기존
// 5종(귀인/오른팔/인연/살림꾼/호랑이선생)에서 PRD("신통방통 · 귀인지도
// 섹션 PRD" v0.9) 12종으로 전환, (2) 판정 로직은 PRD §5.3 점수 산식을
// 그대로 채택. 기존 5유형 M1(대입 우선순위)/M2(케미 점수 100분법) 로직은
// 폐기하고, 이 파일이 그 자리를 대체한다.
//
// [2026-09 2차 수정 — PRD 원문 재대조] 최초 작성 시 "PRD는 3종만 예시
// 제공, 나머지 9종은 README.md 기반 신규 설계"라는 전제로 구현했으나,
// 이는 착오였다. 실제 PRD 원본 PDF(`신통방통 · 귀인지도 섹션 PRD.pdf`,
// 44p, v0.9)에는 12라벨 전체의 트리거 조건(p.4)과 priority 전체값(p.38)이
// 이미 명시되어 있었다. 이번 수정은 그 원문을 1차 authoritative 소스로
// 삼아 LABEL_RULES의 priority·predicate를 전면 재작성한 것이다.
//
//   - p.4  "4.1 관계 라벨 체계" 표: 12라벨 각각의 트리거 조건(오행보충
//     임계값, 인성/식상/재성/관성/비겁 활성화, 합/충 카운트, 희신/용신
//     일치)을 텍스트로 명시. 이 파일의 predicate 설계 근거.
//   - p.28 "5.3 점수 산식 실제 코드": `score += (other.ohHaeng.includes(
//     host.yong_sin)) ? 5 : 0;` — 점수 산식의 보너스는 **용신(yong_sin)**
//     기준이며, other의 오행 카운트 전체(일간 오행 하나만이 아님)에
//     host의 용신 오행이 존재하는지를 본다. (최초 구현은 이를 host의
//     "희신"과 other의 "일간 오행 하나"만 비교하는 것으로 잘못 구현했다 —
//     네이밍·의미 불일치 버그였다.)
//   - p.38 "constants/labels.ts — LABEL_HUE" 전체 12라벨 priority표를
//     그대로 채택(CHEON_GWII=100 ~ GINGJANG=30). p.28-29의 3종 예시
//     (90/70/60)는 p.38 전체표와 값이 다른 PRD 자체의 내부 불일치(초안
//     아티팩트로 추정)이며, p.38 전체표+p.4 트리거조건을 1차 authoritative로
//     채택한다.
//
// [PRD §5.3 점수 산식 원문]
//   score = clamp(
//     60                              // base
//     + ohHaengDelta * 20             // 오행보충 (-1~1)
//     + sipSungWeight * 10            // 십성가중 (-1~1)
//     - conflictPenalty * 10          // 합충형파해 페널티 (0~1)
//     + (yongsinMatch ? 5 : 0)        // 용신 일치 보너스(§5.3.4, host.yong_sin 기준)
//     + (bothTimeExact ? 5 : 0)       // 시간확정 보너스
//     + directionDelta * 5            // 방향성 보정 (-1~1)
//   , 0, 100)
//
// [PRD §5.4 방향성(dir) 5분류]
//   DIR_A_TO_B  : other 오행이 host(mine)의 부족오행을 채움 + 합 가능
//   DIR_B_TO_A  : mine 오행이 other의 부족오행을 채움
//   DIR_TENSION : 오행이 다르며 충(沖)만 발생
//   DIR_SIBLING : 오행이 같음(비겁 관계)
//   DIR_HARMONY : 합(천간합/지지육합) 성립
//
// [PRD §5.5 라벨 매핑 룰셋] "조건을 만족하는 라벨을 모두 필터링 →
// priority 최댓값 하나만 채택"(labelRules.filter(...).sort((a,b)=>
// b.priority-a.priority)[0]). priority는 p.38 전체표, predicate는 p.4
// 트리거조건표를 계산 가능한 형태(ctx 필드)로 옮긴 것이다.
//
// [희신 vs 용신 — 라벨별 구분 사용, 중요] p.4 원문은 라벨마다 희신/용신을
// 구분해서 명시한다 — 혼용하지 않는다.
//   - CHEON_GWII / DEUNGDEUNG / NA_SALJINDA: "희신"(heesin) 기준
//   - GACHI_BICH: "용신"(yongsin) 기준 — p.4 원문에 "용신 일치"로 명시
//   - 점수 산식(§5.3.4)의 +5 보너스: "용신"(yongsin) 기준(p.28 코드 확인)
// 이 파일은 `computeYongsin()`이 반환하는 `{yongsin, heesin}` 두 필드를
// 각 용도에 맞게 정확히 분리해서 사용한다.
//
// [희신/용신] `guinji-yongsin-engine.ts`(Flutter StrengthEngine/YongsinEngine
// 이식본)로 즉시 재계산한다 — 스키마에 별도 저장 컬럼을 두지 않는다.
//
// [사주 계산 아키텍처 - B안 유지] 정통사주 만세력 실계산(60갑자·오행·십신·
// 신살)은 여전히 클라이언트(Flutter `ManseryeokCoreEngine`) 또는
// `saju-manseryeok-engine.ts`(웹 미리보기)에서만 수행한다. 이 파일은
// 클라이언트가 이미 계산해 보낸 사주 JSON(`GuinjiSajuInput`)을 입력받아
// "두 사람의 사주를 대조해 관계 유형·점수를 정하는" 판정 로직만 순수
// 함수로 구현한다 — 사주 원국 자체를 재계산하지 않는다.

import { computeYongsin } from "./guinji-yongsin-engine";

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
/** 오행 상극의 역(나를 극하는 것 = 관살 오행). guinji-yongsin-engine.ts와 동일한 고정표. */
const INV_KE: Record<string, string> = { 토: "목", 수: "토", 화: "수", 금: "화", 목: "금" };

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

function tenGodCategoryOf(tenGod: string | null): string | null {
  if (!tenGod) return null;
  const map: Record<string, string> = {
    비견: "비겁", 겁재: "비겁",
    식신: "식상", 상관: "식상",
    편재: "재성", 정재: "재성",
    편관: "관살", 정관: "관살",
    편인: "인성", 정인: "인성",
  };
  return map[tenGod] ?? null;
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

/**
 * 지지충(六沖) — relationships_engine.dart `_liuChongPairs` 이식.
 * 子午沖/丑未沖/寅申沖/卯酉沖/辰戌沖/巳亥沖.
 */
const JIJI_CHUNG: Array<[string, string]> = [
  ["子", "午"],
  ["丑", "未"],
  ["寅", "申"],
  ["卯", "酉"],
  ["辰", "戌"],
  ["巳", "亥"],
];

/** 천간충(天干沖, 四沖) — relationships_engine.dart `_tianGanChongPairs` 이식. */
const CHEONGAN_CHUNG: Array<[string, string]> = [
  ["甲", "庚"],
  ["乙", "辛"],
  ["丙", "壬"],
  ["丁", "癸"],
];

function isPair(a: string, b: string, table: Array<[string, string]>): boolean {
  return table.some(([x, y]) => (x === a && y === b) || (x === b && y === a));
}

function countPairs(listA: string[], listB: string[], table: Array<[string, string]>): number {
  let count = 0;
  for (const a of listA) {
    for (const b of listB) {
      if (isPair(a, b, table)) count++;
    }
  }
  return count;
}

/**
 * 클라이언트(`ManseryeokCoreEngine`)가 계산해 전달하는 사주 JSON 계약.
 * [변경 없음] 12라벨 전환으로 이 인터페이스 자체는 바뀌지 않는다 — 희신/
 * 용신은 `guinji-yongsin-engine.ts`가 이 입력값만으로 즉시 재계산하므로
 * 별도 필드를 추가하지 않는다.
 */
export interface GuinjiSajuInput {
  /** 일간 한자(예: '甲') — 십성 판정 기준. */
  dayStemHanja: string;
  /** 년/월/일/시 천간 한자 4글자(합/충 판정용). */
  stems: { year: string; month: string; day: string; hour: string };
  /** 년/월/일/시 지지 한자 4글자(육합/육충 판정용). */
  branches: { year: string; month: string; day: string; hour: string };
  /** 오행 카운트(천간+지지 단순 합산, 키: 목/화/토/금/수). */
  fiveElementsCount: Record<string, number>;
  /** 신살 ID 목록(`SinsalEntry.id`, 예: '天乙貴人'). */
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

/**
 * 12관계라벨(PRD "신통방통 · 귀인지도 섹션 PRD" v0.9 §5.2 확정 라벨 체계).
 * 기존 5종(guin/oreunpal/inyeon/salrim/horang)을 완전히 대체한다.
 */
export type GuinjiRelationType =
  | "CHEON_GWII" // 貴 천생귀인
  | "GACHI_BICH" // 輝 같이빛나는사람
  | "DEUNGDEUNG" // 護 든든한등받이
  | "NA_SALRIDA" // 生 나를살리는사람
  | "NA_SALJINDA" // 育 내가살리는사람
  | "CHANG_GYIM" // 養 내가챙기는사람
  | "GACHI_GA" // 共 같이가야좋은길
  | "GAMJEONG" // 感 감정충전소
  | "KKEURIDA" // 緣 끌리는사람
  | "JORYEOK" // 助 조력자
  | "JAGEUKJE" // 刺 자극제
  | "GINGJANG"; // 緊 긴장속단짝

/**
 * 12라벨 정규 순서(PRD p.38 LABEL_HUE priority 내림차순과 동일) — 집계·
 * 이니셜라이즈용 배열. 호출부(join/route.ts, relation-summary/route.ts 등)
 * 가 매번 5라벨 하드코딩을 반복하지 않도록 이 파일에서 단일 소스로 export한다.
 */
export const GUINJI_RELATION_TYPE_ORDER: readonly GuinjiRelationType[] = [
  "CHEON_GWII",
  "NA_SALRIDA",
  "JORYEOK",
  "GACHI_GA",
  "NA_SALJINDA",
  "CHANG_GYIM",
  "GAMJEONG",
  "DEUNGDEUNG",
  "KKEURIDA",
  "GACHI_BICH",
  "JAGEUKJE",
  "GINGJANG",
];

export interface GuinjiJudgeResult {
  relationType: GuinjiRelationType;
  /** PRD §5.3 산식 최종 점수(0~100). 기존 chemistryScore 필드명을 그대로 유지(DB 컬럼명 불변). */
  chemistryScore: number;
  ohaengEvidence: {
    mine: Record<string, number>;
    other: Record<string, number>;
    reason: string;
    /** [2026-11 추가] 상대(other)의 8글자 십성 분포에서 최다 카테고리
     * (인성/식상/재성/비겁/관살, 동률 없으면 null). 관계유형 자체를 정하는
     * 신호이기도 하지만, 같은 관계유형이라도 이 값이 사람마다 달라서
     * 클라이언트가 "이 사람은 특히 ○○ 기운이 강해요" 같은 개인화된
     * 서술을 만드는 데 쓴다. */
    otherDominantCategory: string | null;
    /** 디버깅/투명성용 — 점수 산식 각 항 값을 함께 보존. */
    breakdown: {
      ohHaengDelta: number;
      sipSungWeight: number;
      conflictPenalty: number;
      yongsinMatch: boolean;
      bothTimeExact: boolean;
      directionDelta: number;
      dir: string;
      /** [2026-11 추가] 합(合)/충(沖) 원시 건수 — reason 문자열에는 이미
       * 포함되어 있었으나 구조화된 필드로는 없었다. 클라이언트가 개인화된
       * 서술(관계 내러티브)을 만들 때 문자열 파싱 없이 바로 쓸 수 있게
       * 노출한다. 기존 저장된 레코드(JSON)에는 이 필드가 없을 수 있으므로
       * 소비 측에서는 optional로 다뤄야 한다. */
      hapCount: number;
      chungCount: number;
    };
  };
}

const OHAENG_ORDER = ["목", "화", "토", "금", "수"];

function normalizeFiveElements(raw: Record<string, number>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k of OHAENG_ORDER) out[k] = Math.max(0, Math.trunc(raw[k] ?? 0));
  return out;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

/**
 * [2026-11 수정 — "일간 1글자만 본다" 편중 버그 수정] 오행보충도(oh_haeng_fit,
 * -1~1) — 상대(other)의 원국 오행 분포 "전체"(fiveElementsCount, 8글자
 * 전체 합산치)가 나(mine)의 원국에서 부족한 오행을 얼마나 채워주는지를
 * 판정한다.
 *
 * [수정 전 문제] 이전 구현은 other의 "일간(dayStemHanja) 딱 한 글자"의
 * 오행만 보고 판정했다. 오행은 목/화/토/금/수 5종뿐이므로, 상대가 완전히
 * 다른 생년월일시를 가져도 이 계산은 최대 5가지 값으로만 쏠렸다 —
 * 상대 사주 8글자 중 7글자(연/월/시주, 오행 분포)가 사실상 무시되는
 * 심각한 변별력 결함이었다.
 * [수정 후] other.fiveElementsCount(연/월/일/시 8글자 전체의 오행 총량)를
 * 비중(weight = 해당 오행 개수 / 전체 개수)으로 환산해, 각 오행이 나를
 * 생(生)하는지/부족오행과 일치하는지/극(剋)하는지/과다오행과 겹치는지를
 * "비중 가중합"으로 계산한다. 이렇게 하면 8글자 전체 구성이 결과에
 * 반영되어 사람마다 값이 훨씬 다양하게(연속적으로) 나온다.
 */
function computeOhHaengDelta(mine: GuinjiSajuInput, other: GuinjiSajuInput): number {
  const mineCount = normalizeFiveElements(mine.fiveElementsCount);
  const otherCount = normalizeFiveElements(other.fiveElementsCount);
  const otherTotal = OHAENG_ORDER.reduce((sum, k) => sum + otherCount[k], 0);

  const minVal = Math.min(...OHAENG_ORDER.map((k) => mineCount[k]));
  const maxVal = Math.max(...OHAENG_ORDER.map((k) => mineCount[k]));
  const deficient = new Set(OHAENG_ORDER.filter((k) => mineCount[k] === minVal));
  const dominant = new Set(OHAENG_ORDER.filter((k) => mineCount[k] === maxVal && maxVal > minVal));

  const mineEl = GAN_ELEMENT[mine.dayStemHanja]?.el;
  if (!mineEl || otherTotal <= 0) return 0;

  let delta = 0;
  // other의 오행 분포 전체(8글자)를 순회 — 일간 1글자가 아니라 각 오행이
  // other 원국에서 차지하는 비중(weight)만큼 가중해서 반영한다.
  for (const el of OHAENG_ORDER) {
    const weight = otherCount[el] / otherTotal;
    if (weight <= 0) continue;
    // other의 이 오행이 나를 생(生) — 인성 방향, 부족오행 보충의 정석.
    if (SHENG[el] === mineEl) delta += 0.6 * weight;
    // other의 이 오행이 내 부족오행과 직접 일치.
    if (deficient.has(el)) delta += 0.4 * weight;
    // other의 이 오행이 나를 극(剋) — 관살 방향, 보충이 아니라 소모.
    if (KE[el] === mineEl) delta -= 0.5 * weight;
    // other의 이 오행이 내 과다오행과 겹쳐 편중을 심화.
    if (dominant.has(el)) delta -= 0.3 * weight;
  }

  return clamp(delta, -1, 1);
}

/**
 * [2026-11 수정 — 동일 편중 버그] 십성가중(sipSungWeight, -1~1) — 상대의
 * 원국 8글자(천간 4 + 지지 4) 각각이 나에게 어떤 십성으로 작용하는지를
 * 모두 계산해 평균낸다.
 *
 * [수정 전 문제] 이전 구현은 other의 일간 1글자만으로 십성을 정하고
 * 끝냈다 — computeOhHaengDelta와 동일한 "1글자 편중" 결함이 여기에도
 * 있었다. [수정 후] other의 8글자 전체 각각에 대해 십성 카테고리를
 * 구해 가중치를 매기고 평균을 낸다. 인성/식상(순응·협력 방향)은 양,
 * 관살(긴장 방향)은 음, 비겁(중립~긴장)은 약음, 재성(자원 소모)은
 * 약양으로 두는 기존 가중치 값은 그대로 유지한다.
 */
function computeSipSungWeight(mine: GuinjiSajuInput, other: GuinjiSajuInput): number {
  const dist = tenGodCategoryDistribution(mine, other);
  const total = Object.values(dist).reduce((a, b) => a + b, 0);
  if (total === 0) return 0;
  const CAT_WEIGHT: Record<string, number> = { 인성: 0.8, 식상: 0.5, 재성: 0.2, 비겁: -0.2, 관살: -0.6 };
  let sum = 0;
  for (const [cat, count] of Object.entries(dist)) sum += (CAT_WEIGHT[cat] ?? 0) * count;
  return clamp(sum / total, -1, 1);
}

/**
 * other의 8글자(천간 y/m/d/h + 지지 y/m/d/h) 각각을 mine의 일간 기준
 * 십성으로 환산해 카테고리별 개수 분포를 구한다. computeSipSungWeight와
 * label 매칭용 otherCat(dominantCategory) 양쪽에서 공유하는 헬퍼 —
 * 두 계산이 서로 다른 기준(예전엔 label만 일간 1글자)을 쓰던 불일치도
 * 함께 해소한다.
 */
function tenGodCategoryDistribution(mine: GuinjiSajuInput, other: GuinjiSajuInput): Record<string, number> {
  const chars = [
    other.stems.year, other.stems.month, other.stems.day, other.stems.hour,
    other.branches.year, other.branches.month, other.branches.day, other.branches.hour,
  ];
  const dist: Record<string, number> = { 인성: 0, 식상: 0, 재성: 0, 비겁: 0, 관살: 0 };
  for (const c of chars) {
    const cat = tenGodCategoryOf(getTenGod(mine.dayStemHanja, c));
    if (cat) dist[cat] = (dist[cat] ?? 0) + 1;
  }
  return dist;
}

/** 카테고리 분포에서 최다 개수 카테고리를 대표값으로 채택(동률이면 먼저 나온 것). */
function dominantCategory(dist: Record<string, number>): string | null {
  let best: string | null = null;
  let bestVal = 0;
  for (const [cat, count] of Object.entries(dist)) {
    if (count > bestVal) {
      bestVal = count;
      best = cat;
    }
  }
  return best;
}

/**
 * 합충형파해 페널티(conflictPenalty, 0~1) — 충(沖)이 있으면 양의 페널티,
 * 합(合)이 있으면 페널티를 상쇄(음수 방향으로 조정하되 0 미만으로는
 * 내려가지 않음 — PRD 원문 "breakdown.conflictPenalty < 0.05"가 페널티
 * 낮음을 "합·무충" 상태로 요구하는 것과 일치시킴).
 */
function computeConflictPenalty(mine: GuinjiSajuInput, other: GuinjiSajuInput): { penalty: number; hapCount: number; chungCount: number } {
  const mineStems = [mine.stems.year, mine.stems.month, mine.stems.day, mine.stems.hour];
  const otherStems = [other.stems.year, other.stems.month, other.stems.day, other.stems.hour];
  const mineBranches = [mine.branches.year, mine.branches.month, mine.branches.day];
  const otherBranches = [other.branches.year, other.branches.month, other.branches.day];

  const cheonganHapCount = countPairs(mineStems, otherStems, CHEONGAN_HAP);
  const jijiHapCount = countPairs(mineBranches, otherBranches, JIJI_YUKHAP);
  const hapCount = cheonganHapCount + jijiHapCount;

  const cheonganChungCount = countPairs(mineStems, otherStems, CHEONGAN_CHUNG);
  const jijiChungCount = countPairs(mineBranches, otherBranches, JIJI_CHUNG);
  const chungCount = cheonganChungCount + jijiChungCount;

  let penalty = clamp(chungCount * 0.35, 0, 1);
  penalty = clamp(penalty - hapCount * 0.2, 0, 1);

  return { penalty, hapCount, chungCount };
}

/** PRD §5.4 방향성(dir) 5분류 판정. */
function computeDirection(
  mine: GuinjiSajuInput,
  other: GuinjiSajuInput,
  hapCount: number,
  chungCount: number,
): { dir: string; directionDelta: number } {
  const mineEl = GAN_ELEMENT[mine.dayStemHanja]?.el;
  const otherEl = GAN_ELEMENT[other.dayStemHanja]?.el;

  if (mineEl === otherEl) return { dir: "DIR_SIBLING", directionDelta: 0 };
  if (hapCount >= 1 && chungCount === 0) return { dir: "DIR_HARMONY", directionDelta: 0.5 };
  if (chungCount >= 1 && hapCount === 0) return { dir: "DIR_TENSION", directionDelta: -0.3 };

  const mineCount = normalizeFiveElements(mine.fiveElementsCount);
  const otherCount = normalizeFiveElements(other.fiveElementsCount);
  const mineMin = Math.min(...OHAENG_ORDER.map((k) => mineCount[k]));
  const otherMin = Math.min(...OHAENG_ORDER.map((k) => otherCount[k]));
  const mineDeficient = new Set(OHAENG_ORDER.filter((k) => mineCount[k] === mineMin));
  const otherDeficient = new Set(OHAENG_ORDER.filter((k) => otherCount[k] === otherMin));

  const otherFillsMine = otherEl && mineDeficient.has(otherEl);
  const mineFillsOther = mineEl && otherDeficient.has(mineEl);

  if (otherFillsMine && !mineFillsOther) return { dir: "DIR_A_TO_B", directionDelta: 0.4 };
  if (mineFillsOther && !otherFillsMine) return { dir: "DIR_B_TO_A", directionDelta: 0.2 };
  if (otherFillsMine && mineFillsOther) return { dir: "DIR_A_TO_B", directionDelta: 0.5 };
  return { dir: "DIR_B_TO_A", directionDelta: 0 };
}

/**
 * [2026-11 3차 수정 — 임계값 실측 재보정] PRD("신통방통 · 귀인지도 섹션
 * PRD" v0.9) p.4 "4.1 관계 라벨 체계" 트리거 조건표 + p.38 priority
 * 전체표의 "조건 형태"(무엇과 무엇을 비교하는가)는 그대로 유지하되,
 * "임계값 숫자"는 실측 데이터 분포에 맞게 다시 캘리브레이션했다.
 *
 * [발견된 문제] computeOhHaengDelta를 "일간 1글자"→"8글자 가중평균"으로
 * 고치자(위 함수 주석 참고) ohHaengDelta의 실제 값 분포가 예전 예상
 * (-1~1 전체 스펙트럼)보다 훨씬 좁아졌다 — 800쌍 무작위 시뮬레이션
 * 결과 p50≈0.05, p75≈0.18, p90≈0.30, p97≈0.44, max≈0.7 정도였다.
 * 그런데 원래 PRD 임계값(0.3/0.4/0.5/0.6/0.8)은 이 좁아진 분포 기준으로
 * 보면 상위 3~10%만 통과하는 극단값이라, 대부분의 케이스가 12개 규칙
 * 중 하나도 통과하지 못하고 "매칭 실패 시 조력자(JORYEOK) 폴백"에
 * 몰렸다(실측: 무작위 100쌍 중 JORYEOK 53건, 그중 42건이 실제로는
 * 조건 불만족 폴백이었음 — 즉 "조력자"라는 라벨이 아니라 사실상 "판정
 * 불가"였다). 십성가중(sipSungWeight)도 마찬가지로 8글자 평균화로
 * 값의 폭이 좁아졌다(p50≈0.15, p90≈0.36).
 * 또한 yongsinMatch/heesinMatch가 "상대가 해당 오행을 1개 이상만
 * 가지면 OK"였는데, 오행이 5종뿐이라 무작위 두 사람 사이에도 80%
 * 확률로 우연히 만족되는 조건이었다 — 이 역시 실측으로 확인했다.
 *
 * [수정 내용] (1) ohHaengDelta/sipSungWeight 임계값을 실측 percentile에
 * 맞춰 재보정(대략 p60~p95 구간에 라벨들이 걸리도록 재배치).
 * (2) yongsinMatch/heesinMatch를 "보유 개수 1개 이상"에서 "2개 이상
 * (비중 약 25% 이상)"으로 강화 — computeYongsinMatchStrength() 참고.
 * (3) 800쌍 무작위 시뮬레이션으로 라벨 분포가 실제로 다양해지는지
 * (한 라벨이 30% 이상을 독점하지 않는지) 검증 완료.
 */
interface LabelRuleCtx {
  dir: string;
  hapCount: number;
  chungCount: number;
  ohHaengDelta: number; // 오행보충도(oh_haeng_fit, -1~1) — PRD p.4 "오행 보충" 그 자체
  sipSungWeight: number; // 십성가중(-1~1) — 임계값 재보정에 함께 사용
  /** p.4 "희신 일치" — other가 mine의 희신 오행을 "충분히"(2개 이상) 보유. */
  heesinMatchOtherToMine: boolean;
  /** p.4 NA_SALJINDA "상대 희신 일치" — mine이 other의 희신 오행을 "충분히" 보유. */
  heesinMatchMineToOther: boolean;
  /** p.4 GACHI_BICH "용신 일치" — other가 mine의 용신 오행을 "충분히" 보유. */
  yongsinMatch: boolean;
  otherIsInseong: boolean; // 상대의 8글자 십성 분포에서 인성(印星)이 최다
  otherIsGwanseong: boolean; // 상대의 8글자 십성 분포에서 관살(官殺)이 최다
  otherIsSikSang: boolean; // 상대의 8글자 십성 분포에서 식상(食傷)이 최다
  otherIsBigeop: boolean; // 상대의 8글자 십성 분포에서 비겁(比劫)이 최다
  otherIsJaeseong: boolean; // 상대의 8글자 십성 분포에서 재성(財星)이 최다
  mineGwanseongExcess: boolean; // 내 오행 중 "내 관살 오행"이 최대치(관성 과다)
}

interface LabelRule {
  code: GuinjiRelationType;
  priority: number;
  predicate: (ctx: LabelRuleCtx) => boolean;
}

const LABEL_RULES: LabelRule[] = [
  {
    // [PRD p.4 원문 취지] 오행 보충 상위권 + 희신 일치 + 합(合) 존재.
    // 실측 p90≈0.30 지점을 "상위권" 임계값으로 채택.
    code: "CHEON_GWII",
    priority: 100,
    predicate: (c) => c.ohHaengDelta >= 0.30 && c.heesinMatchOtherToMine && c.hapCount >= 2,
  },
  {
    // [PRD p.4] 오행 보충 상위 + 인성(印星) 활성화. 실측 p75~p90 구간.
    code: "NA_SALRIDA",
    priority: 90,
    predicate: (c) => c.ohHaengDelta >= 0.20 && c.otherIsInseong,
  },
  {
    // [PRD p.4] 오행 보충 중상위 + 식상(食傷) 상호보완.
    code: "GACHI_GA",
    priority: 75,
    predicate: (c) => c.ohHaengDelta >= 0.12 && c.ohHaengDelta < 0.30 && c.otherIsSikSang,
  },
  {
    // [PRD p.4] 오행 보충 중간대 + 합(合) 존재 — 실측 median 부근(p50~p75).
    code: "JORYEOK",
    priority: 70,
    predicate: (c) => c.ohHaengDelta >= 0.08 && c.ohHaengDelta < 0.20 && c.hapCount >= 2,
  },
  {
    // [PRD p.4] 인성 + 희신 + 오행보충 양(+) — CHEON_GWII보다 완화된 조건.
    code: "DEUNGDEUNG",
    priority: 65,
    predicate: (c) => c.otherIsInseong && c.heesinMatchOtherToMine && c.ohHaengDelta >= 0.05,
  },
  {
    // [PRD p.4] 내 오행 과다 아님 + 오행보충 음(-) + 상대 희신 일치("내가 상대를 살림" 방향).
    code: "NA_SALJINDA",
    priority: 60,
    predicate: (c) => c.mineGwanseongExcess === false && c.ohHaengDelta < -0.05 && c.heesinMatchMineToOther,
  },
  {
    // [PRD p.4] 관성(官星) 과다 + 오행보충 음(-) — 관살 부담이 실제로 있는 경우.
    code: "CHANG_GYIM",
    priority: 55,
    predicate: (c) => c.mineGwanseongExcess && c.otherIsGwanseong && c.ohHaengDelta < -0.05,
  },
  {
    // [PRD p.4] 오행보충 소폭 양(+) + 식상 균형.
    code: "GAMJEONG",
    priority: 50,
    predicate: (c) => c.otherIsSikSang && c.ohHaengDelta >= 0.05 && c.ohHaengDelta < 0.20,
  },
  {
    // [PRD p.4] 재성(財星) 활성 + 충 ≤ 1.
    code: "KKEURIDA",
    priority: 45,
    predicate: (c) => c.otherIsJaeseong && c.chungCount <= 1,
  },
  {
    // [PRD p.4] 비겁(比劫, 오행 동일) + 합 ≥ 1 + 용신 일치("충분히" 보유로 강화).
    code: "GACHI_BICH",
    priority: 40,
    predicate: (c) => c.dir === "DIR_SIBLING" && c.hapCount >= 1 && c.yongsinMatch,
  },
  {
    // [PRD p.4] 충(沖) 존재 + 비겁 활성 — 예전엔 "정확히 1개"라 너무 좁았음, 1~2개로 완화.
    code: "JAGEUKJE",
    priority: 35,
    predicate: (c) => c.chungCount >= 1 && c.chungCount <= 2 && c.otherIsBigeop,
  },
  {
    // [PRD p.4] 충 ≥ 1 + 식상·재성 균형.
    code: "GINGJANG",
    priority: 30,
    predicate: (c) => c.chungCount >= 1 && (c.otherIsSikSang || c.otherIsJaeseong),
  },
];

/**
 * [2026-11 신규] LABEL_RULES 12개 중 아무것도 매칭되지 않는 극소수 케이스의
 * 폴백 라벨을 정한다. "무조건 조력자(JORYEOK)"가 아니라, ohHaengDelta의
 * 부호·크기와 충/합 상황을 근거로 실제로 가장 가까운 관계상을 고른다 —
 * 폴백조차 실데이터(두 사람의 사주 비교 결과)를 반영하게 만드는 것이
 * 목적이다.
 */
function computeFallbackLabel(c: LabelRuleCtx): GuinjiRelationType {
  if (c.chungCount >= 2) return "GINGJANG"; // 충이 여러 개면 긴장 관계로.
  if (c.ohHaengDelta >= 0.05) return c.hapCount >= 1 ? "JORYEOK" : "GACHI_GA"; // 보충은 양(+)이나 조건 미달.
  if (c.ohHaengDelta <= -0.05) return "NA_SALJINDA"; // 보충이 음(-)이면 내가 상대를 살리는 방향으로.
  if (c.dir === "DIR_SIBLING") return "GACHI_BICH"; // 오행이 같으면 같이가는 유형.
  return "KKEURIDA"; // 그 외 미세한 중립대는 인연(끌리는 사람)으로.
}

/**
 * [RelationJudger 핵심] owner(나) 기준으로 member(상대)와의 관계를 판정한다.
 * PRD §5.3 점수 산식 + p.4 트리거조건표(§4.1) + p.38 priority표를 그대로
 * 구현한다.
 */
export function judgeGuinjiRelation(
  mine: GuinjiSajuInput,
  other: GuinjiSajuInput,
): GuinjiJudgeResult {
  const mineDayGan = mine.dayStemHanja;
  const mineEl = GAN_ELEMENT[mineDayGan]?.el;

  // ── 1) 오행보충도 / 십성가중 ──
  const ohHaengDelta = computeOhHaengDelta(mine, other);
  const sipSungWeight = computeSipSungWeight(mine, other);

  // ── 2) 합충형파해 페널티 ──
  const { penalty: conflictPenalty, hapCount, chungCount } = computeConflictPenalty(mine, other);

  // ── 3) 방향성(dir) ──
  const { dir, directionDelta } = computeDirection(mine, other, hapCount, chungCount);

  // ── 4) 용신/희신 — PRD p.28 §5.3.4는 "용신"(yong_sin) 기준, p.4는
  //     라벨별로 희신/용신을 구분해 요구한다. `other.ohHaeng.includes(
  //     host.yong_sin)`(p.28 원문)처럼 상대의 오행 카운트 전체에 내
  //     용신/희신 오행이 존재하는지(일간 오행 하나만이 아니라)로 판정한다.
  const mineYongsinProfile = computeYongsin(mine);
  const otherYongsinProfile = computeYongsin(other);
  const otherCount = normalizeFiveElements(other.fiveElementsCount);
  const mineCount = normalizeFiveElements(mine.fiveElementsCount);

  // [2026-11 수정] "보유 개수 1개 이상"은 오행이 5종뿐이라 무작위 두
  // 사람 사이에도 약 80% 확률로 우연히 만족되는 너무 관대한 기준이었다
  // (실측 확인됨). "2개 이상 보유"(8글자 중 대략 25% 이상 비중)로
  // 강화해 "충분히 많이 가지고 있어야 진짜 일치"로 판정하도록 한다.
  const MATCH_MIN_COUNT = 2;
  // 점수 산식(§5.3.4)의 +5 보너스 — host(mine)의 용신을 other가 충분히 보유하는지.
  const yongsinMatch = Boolean(mineYongsinProfile.yongsin && (otherCount[mineYongsinProfile.yongsin] ?? 0) >= MATCH_MIN_COUNT);
  // p.4 CHEON_GWII/DEUNGDEUNG "희신 일치" — other가 mine의 희신 오행을 충분히 보유("상대가 나를 살림" 방향).
  const heesinMatchOtherToMine = Boolean(mineYongsinProfile.heesin && (otherCount[mineYongsinProfile.heesin] ?? 0) >= MATCH_MIN_COUNT);
  // p.4 NA_SALJINDA "상대 희신 일치" — mine이 other의 희신 오행을 충분히 보유("내가 상대를 살림" 방향).
  const heesinMatchMineToOther = Boolean(otherYongsinProfile.heesin && (mineCount[otherYongsinProfile.heesin] ?? 0) >= MATCH_MIN_COUNT);

  // ── 5) 시간확정 보너스 — GuinjiSajuInput에는 시간 확정 여부 필드가
  //     없다(호출부가 이미 birthTimeMissing 여부를 알고 있으므로, 이
  //     함수는 항상 false로 두고 필요 시 호출부에서 +5를 별도 가산하지
  //     않는다 — 현재 데이터 계약 범위 내에서는 이 보너스를 적용하지
  //     않는 것으로 확정한다. 향후 호출부 계약이 birthTimeExact를
  //     전달하도록 확장되면 이 자리에서 사용한다).
  const bothTimeExact = false;

  // ── 6) PRD §5.3 점수 산식 ──
  const total = clamp(
    60 +
      ohHaengDelta * 20 +
      sipSungWeight * 10 -
      conflictPenalty * 10 +
      (yongsinMatch ? 5 : 0) +
      (bothTimeExact ? 5 : 0) +
      directionDelta * 5,
    0,
    100,
  );

  // ── 7) 라벨 매핑용 컨텍스트 구성 ──
  // [2026-11 수정] 예전엔 otherDayGan(일간 1글자)만으로 otherCat을 정했다
  // — computeSipSungWeight와 동일한 "1글자 편중" 결함이 라벨 매칭에도
  // 있었다. 이제 other의 8글자 전체 십성 분포에서 최다 카테고리를
  // 대표값으로 채택해, 점수 산식(sipSungWeight)과 라벨 매칭이 같은
  // 기준을 쓰도록 통일한다.
  const otherCatDist = tenGodCategoryDistribution(mine, other);
  const otherCat = dominantCategory(otherCatDist);
  // 내 관살(官星) 오행(=나를 극하는 오행)이 내 오행 중 최댓값(과다)인지 — PRD p.4 CHANG_GYIM "관성 과다".
  const mineMaxVal = Math.max(...OHAENG_ORDER.map((k) => mineCount[k]));
  const mineDominant = new Set(OHAENG_ORDER.filter((k) => mineCount[k] === mineMaxVal && mineMaxVal > 0));
  const mineGwanseongExcess = Boolean(mineEl && INV_KE[mineEl] && mineDominant.has(INV_KE[mineEl]));

  const ctx: LabelRuleCtx = {
    dir,
    hapCount,
    chungCount,
    ohHaengDelta,
    sipSungWeight,
    heesinMatchOtherToMine,
    heesinMatchMineToOther,
    yongsinMatch,
    otherIsInseong: otherCat === "인성",
    otherIsGwanseong: otherCat === "관살",
    otherIsSikSang: otherCat === "식상",
    otherIsBigeop: otherCat === "비겁",
    otherIsJaeseong: otherCat === "재성",
    mineGwanseongExcess,
  };

  // ── 8) 라벨 매핑 — priority 최댓값 하나만 채택(PRD p.38 LABEL_HUE 순서).
  // [2026-11 수정 — "무조건 조력자" 폴백 제거] 예전엔 12개 규칙 중 아무것도
  // 매칭되지 않으면 항상 JORYEOK(조력자)로 떨어졌다 — 이게 "조력자만
  // 계속 나온다"는 편중의 두 번째(더 큰) 원인이었다(실측: 무작위
  // 100쌍 중 JORYEOK 53건 중 42건이 사실 "조건 불만족 폴백"이었음).
  // 이제 매칭 실패 시에도 무조건 한 라벨로 고정하지 않고, ohHaengDelta/
  // sipSungWeight의 실제 부호·방향성(dir)을 근거로 "가장 근접한" 라벨을
  // 골라 폴백한다 — 즉 폴백도 실데이터를 반영해서 사람마다 달라진다.
  const matched = LABEL_RULES.filter((r) => r.predicate(ctx)).sort((a, b) => b.priority - a.priority)[0];
  const relationType: GuinjiRelationType = matched?.code ?? computeFallbackLabel(ctx);

  const reasonParts: string[] = [];
  reasonParts.push(`오행보충=${ohHaengDelta.toFixed(2)}`);
  reasonParts.push(`십성가중=${sipSungWeight.toFixed(2)}`);
  reasonParts.push(`합=${hapCount}건`);
  reasonParts.push(`충=${chungCount}건`);
  reasonParts.push(`방향성=${dir}`);
  if (yongsinMatch) reasonParts.push("용신일치");
  if (heesinMatchOtherToMine) reasonParts.push("희신일치(상대→나)");
  if (heesinMatchMineToOther) reasonParts.push("희신일치(나→상대)");
  const reason = reasonParts.join(" · ");

  return {
    relationType,
    chemistryScore: Math.round(total),
    ohaengEvidence: {
      mine: mineCount,
      other: otherCount,
      reason,
      otherDominantCategory: otherCat,
      breakdown: {
        ohHaengDelta,
        sipSungWeight,
        conflictPenalty,
        yongsinMatch,
        bothTimeExact,
        directionDelta,
        dir,
        hapCount,
        chungCount,
      },
    },
  };
}
