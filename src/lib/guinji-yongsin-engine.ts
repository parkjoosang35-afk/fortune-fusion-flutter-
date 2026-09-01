// 귀인지도 12라벨 판정용 — 희신(喜神)/용신(用神)/신강신약(身强身弱)
// 정밀 분석 엔진(서버 이식본).
//
// [이식 출처] Flutter `lib/features/home/domain/manseryeok/strength_engine.dart`
// + `yongsin_engine.dart` + `hidden_stems_engine.dart` + `five_elements_engine.dart`
// (정통사주 80종 전용 신규 엔진, PHASE 2~3). 이 파일은 그 로직을 그대로
// TypeScript로 옮긴 것이며 새로운 명리 판정 규칙을 만들지 않는다.
//
// [입력 제약 — 중요] 이 엔진은 `GuinjiSajuInput`(dayStemHanja/stems/branches/
// fiveElementsCount)만으로 지장간·통근·설기까지 전부 재구성한다. 스키마에
// 새 필드(희신/용신 저장 컬럼)를 추가하지 않고, 판정이 필요할 때마다 이
// 입력값으로부터 즉시 재계산한다 — 기존 6개 지도/19개 멤버의 저장된
// `sajuParsed`(GuinjiSajuInput 형식)를 그대로 재사용할 수 있다.
//
// [기존 saju-manseryeok-engine.ts의 judgeStrength()와의 관계] 그 함수는
// "간이 버전"(오행 개수 비율만 봄)이며 웹 미리보기 표시용으로만 쓰인다.
// 이 파일의 StrengthEngine.analyze()는 지장간 통근까지 반영하는 정밀
// 버전으로, 귀인지도 12라벨 판정(희신 일치 여부)에만 사용한다. 두 함수는
// 서로 다른 용도로 공존하며 대체 관계가 아니다.

import { GuinjiSajuInput } from "./guinji-relation-judger";

const GAN_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  甲: { el: "목", yy: "양" }, 乙: { el: "목", yy: "음" },
  丙: { el: "화", yy: "양" }, 丁: { el: "화", yy: "음" },
  戊: { el: "토", yy: "양" }, 己: { el: "토", yy: "음" },
  庚: { el: "금", yy: "양" }, 辛: { el: "금", yy: "음" },
  壬: { el: "수", yy: "양" }, 癸: { el: "수", yy: "음" },
};

const ZHI_ELEMENT: Record<string, { el: string; yy: "양" | "음" }> = {
  子: { el: "수", yy: "양" }, 丑: { el: "토", yy: "음" },
  寅: { el: "목", yy: "양" }, 卯: { el: "목", yy: "음" },
  辰: { el: "토", yy: "양" }, 巳: { el: "화", yy: "음" },
  午: { el: "화", yy: "양" }, 未: { el: "토", yy: "음" },
  申: { el: "금", yy: "양" }, 酉: { el: "금", yy: "음" },
  戌: { el: "토", yy: "양" }, 亥: { el: "수", yy: "음" },
};

const SHENG: Record<string, string> = { 목: "화", 화: "토", 토: "금", 금: "수", 수: "목" };
const KE: Record<string, string> = { 목: "토", 토: "수", 수: "화", 화: "금", 금: "목" };
const INV_SHENG: Record<string, string> = { 화: "목", 토: "화", 금: "토", 수: "금", 목: "수" };
const INV_KE: Record<string, string> = { 토: "목", 수: "토", 화: "수", 금: "화", 목: "금" };

const TEN_GODS_TABLE: Record<string, string> = {
  "same:true": "비견", "same:false": "겁재",
  "生out:true": "식신", "生out:false": "상관",
  "克out:true": "편재", "克out:false": "정재",
  "克in:true": "편관", "克in:false": "정관",
  "生in:true": "편인", "生in:false": "정인",
};

function getTenGod(dayGan: string, target: string): string {
  const day = GAN_ELEMENT[dayGan];
  const tgt = GAN_ELEMENT[target] ?? ZHI_ELEMENT[target];
  const sameYy = day.yy === tgt.yy;
  let rel: string;
  if (day.el === tgt.el) rel = "same";
  else if (SHENG[day.el] === tgt.el) rel = "生out";
  else if (KE[day.el] === tgt.el) rel = "克out";
  else if (KE[tgt.el] === day.el) rel = "克in";
  else if (SHENG[tgt.el] === day.el) rel = "生in";
  else rel = "same";
  return TEN_GODS_TABLE[`${rel}:${sameYy}`];
}

/** 십신 5대 범주 축약. tenGodCategoryOf()(strength_engine.dart) 이식. */
export function tenGodCategoryOf(tenGod: string): string {
  const map: Record<string, string> = {
    비견: "비겁", 겁재: "비겁",
    식신: "식상", 상관: "식상",
    편재: "재성", 정재: "재성",
    편관: "관살", 정관: "관살",
    편인: "인성", 정인: "인성",
  };
  return map[tenGod] ?? tenGod;
}

/** 일간 오행 대비 타겟 오행의 관계 범주. relationCategoryOf() 이식. */
export function relationCategoryOf(dayElement: string, targetElement: string): string {
  if (targetElement === dayElement) return "비겁";
  if (SHENG[dayElement] === targetElement) return "식상";
  if (KE[dayElement] === targetElement) return "재성";
  if (INV_KE[dayElement] === targetElement) return "관살";
  if (INV_SHENG[dayElement] === targetElement) return "인성";
  throw new Error(`알 수 없는 오행 관계: ${dayElement} vs ${targetElement}`);
}

/** 지지 → 지장간 목록. five_elements_engine.dart의 _zhiHideGan 이식. */
const ZHI_HIDE_GAN: Record<string, string[]> = {
  子: ["癸"],
  丑: ["己", "癸", "辛"],
  寅: ["甲", "丙", "戊"],
  卯: ["乙"],
  辰: ["戊", "乙", "癸"],
  巳: ["丙", "庚", "戊"],
  午: ["丁", "己"],
  未: ["己", "丁", "乙"],
  申: ["庚", "壬", "戊"],
  酉: ["辛"],
  戌: ["戊", "辛", "丁"],
  亥: ["壬", "甲"],
};

/** 지장간 개수별 가중치(정기>중기>여기). hiddenStemWeightsForCount() 이식. */
const HIDDEN_STEM_WEIGHTS: Record<number, number[]> = {
  1: [1.0],
  2: [0.7, 0.3],
  3: [0.6, 0.25, 0.15],
};

/** 월지 → 그 계절이 왕성하게 하는 오행(월령). monthBranchToDominantElement 이식. */
const MONTH_BRANCH_TO_DOMINANT_ELEMENT: Record<string, string> = {
  寅: "목", 卯: "목", 辰: "목",
  巳: "화", 午: "화", 未: "화",
  申: "금", 酉: "금", 戌: "금",
  亥: "수", 子: "수", 丑: "수",
};

/** 월지 → 조후법상 특별히 보강이 필요한 오행(간이 조후법). _johuNeedByMonthBranch 이식. */
const JOHU_NEED_BY_MONTH_BRANCH: Record<string, string> = {
  亥: "화", 子: "화", 丑: "화", // 한겨울 — 온난한 화 필요
  巳: "수", 午: "수", 未: "수", // 한여름 — 시원한 수 필요
};

export interface StrengthProfile {
  verdict: "신강" | "중화" | "신약";
  score: number; // 0~1
  monthOrderScore: number;
  rootScore: number;
  supportScore: number;
  controlScore: number;
  drainScore: number;
}

export interface YongsinProfile {
  method: string;
  yongsin: string; // '' = 조후 불요
  heesin: string;
  gisin: string;
  gusin: string;
}

/**
 * 신강/신약 정밀 분석 — `StrengthEngine.analyze()`(strength_engine.dart) 이식.
 * 월령 가중치 2배, 통근(지장간 비겁/인성 가중합산), 생조/극제/설기 종합.
 */
export function analyzeStrength(saju: GuinjiSajuInput): StrengthProfile {
  const dayGan = saju.dayStemHanja;
  const dayElement = GAN_ELEMENT[dayGan].el;
  const MONTH_WEIGHT = 2.0;
  const DRAIN_DAMPING = 0.5;

  // ① 월령(月令) 득실.
  const monthDominantElement = MONTH_BRANCH_TO_DOMINANT_ELEMENT[saju.branches.month];
  const monthRelation = relationCategoryOf(dayElement, monthDominantElement);
  let monthOrderScore: number;
  if (monthRelation === "비겁" || monthRelation === "인성") monthOrderScore = 1.0;
  else if (monthRelation === "관살") monthOrderScore = -1.0;
  else monthOrderScore = -0.5; // 식상 | 재성

  const posWeight = (key: string) => (key === "month_zhi" ? MONTH_WEIGHT : 1.0);

  // ② 통근(通根) — 지지 4곳의 지장간 중 비겁/인성 가중 합산.
  let rootScore = 0;
  const branchPositions: Array<[string, string]> = [
    ["year_zhi", saju.branches.year],
    ["month_zhi", saju.branches.month],
    ["day_zhi", saju.branches.day],
    ["hour_zhi", saju.branches.hour],
  ];
  for (const [posKey, branch] of branchPositions) {
    const hideGans = ZHI_HIDE_GAN[branch] ?? [];
    const weights = HIDDEN_STEM_WEIGHTS[hideGans.length] ?? [1.0];
    for (let i = 0; i < hideGans.length; i++) {
      const tenGod = getTenGod(dayGan, hideGans[i]);
      const cat = tenGodCategoryOf(tenGod);
      if (cat === "비겁" || cat === "인성") {
        rootScore += weights[i] * posWeight(posKey);
      }
    }
  }

  // ③~⑤ 생조(비겁+인성)/극제(관살)/설기(식상+재성) — 천간3(일간 제외)+지지4 본기.
  let supportScore = 0;
  let controlScore = 0;
  let drainScore = 0;
  const tenGodPositions: Array<[string, string]> = [
    ["year_gan", saju.stems.year],
    ["month_gan", saju.stems.month],
    ["hour_gan", saju.stems.hour],
    ["year_zhi", saju.branches.year],
    ["month_zhi", saju.branches.month],
    ["day_zhi", saju.branches.day],
    ["hour_zhi", saju.branches.hour],
  ];
  for (const [key, char] of tenGodPositions) {
    const tenGod = getTenGod(dayGan, char);
    const cat = tenGodCategoryOf(tenGod);
    const w = posWeight(key);
    if (cat === "비겁" || cat === "인성") supportScore += w;
    else if (cat === "관살") controlScore += w;
    else if (cat === "식상" || cat === "재성") drainScore += w;
  }

  const positiveMonth = monthOrderScore > 0 ? monthOrderScore * MONTH_WEIGHT : 0;
  const negativeMonth = monthOrderScore < 0 ? -monthOrderScore * MONTH_WEIGHT : 0;

  const totalPositive = supportScore + rootScore + positiveMonth;
  const totalNegative = controlScore + drainScore * DRAIN_DAMPING + negativeMonth;

  const score = totalPositive + totalNegative === 0
    ? 0.5
    : totalPositive / (totalPositive + totalNegative);

  let verdict: "신강" | "중화" | "신약";
  if (score >= 0.6) verdict = "신강";
  else if (score <= 0.4) verdict = "신약";
  else verdict = "중화";

  return {
    verdict, score, monthOrderScore, rootScore, supportScore, controlScore, drainScore,
  };
}

/** 억부법(抑扶法) — `YongsinEngine.byEokbu()` 이식. */
function byEokbu(saju: GuinjiSajuInput, strength: StrengthProfile): YongsinProfile {
  const dayElement = GAN_ELEMENT[saju.dayStemHanja].el;

  const elementOfCategory = (category: string): string => {
    switch (category) {
      case "비겁": return dayElement;
      case "식상": return SHENG[dayElement];
      case "재성": return KE[dayElement];
      case "관살": return INV_KE[dayElement];
      case "인성": return INV_SHENG[dayElement];
      default: throw new Error(`알 수 없는 범주: ${category}`);
    }
  };

  let priority: string[];
  if (strength.verdict === "신강") priority = ["식상", "재성", "관살"];
  else if (strength.verdict === "신약") priority = ["인성", "비겁"];
  else priority = strength.score >= 0.5 ? ["식상", "재성", "관살"] : ["인성", "비겁"];

  let yongsinCategory: string | undefined;
  for (const cat of priority) {
    const el = elementOfCategory(cat);
    if ((saju.fiveElementsCount[el] ?? 0) > 0) {
      yongsinCategory = cat;
      break;
    }
  }
  yongsinCategory ??= priority[0];
  const yongsinElement = elementOfCategory(yongsinCategory);

  const heesinElement = INV_SHENG[yongsinElement];
  const gisinElement = INV_KE[yongsinElement];
  const gusinElement = INV_SHENG[gisinElement];

  return { method: "억부", yongsin: yongsinElement, heesin: heesinElement, gisin: gisinElement, gusin: gusinElement };
}

/** 조후법(調候法) — `YongsinEngine.byJohu()` 이식(간이 조후법). */
function byJohu(saju: GuinjiSajuInput): YongsinProfile {
  const monthBranch = saju.branches.month;
  const need = JOHU_NEED_BY_MONTH_BRANCH[monthBranch];
  if (!need) {
    return { method: "조후", yongsin: "", heesin: "", gisin: "", gusin: "" };
  }
  const heesinElement = INV_SHENG[need];
  const gisinElement = INV_KE[need];
  const gusinElement = INV_SHENG[gisinElement];
  return { method: "조후", yongsin: need, heesin: heesinElement, gisin: gisinElement, gusin: gusinElement };
}

/**
 * 억부+조후 종합 — `YongsinEngine.combine()` 이식("조후 우선 원칙").
 * 12라벨 판정에서 이 함수의 결과(`heesin`)를 "희신 일치" 조건에 사용한다.
 */
export function computeYongsin(saju: GuinjiSajuInput): YongsinProfile {
  const strength = analyzeStrength(saju);
  const eokbu = byEokbu(saju, strength);
  const johu = byJohu(saju);

  if (johu.yongsin === "") return eokbu;
  if (johu.yongsin === eokbu.yongsin) return eokbu;
  return johu; // 조후 우선 원칙.
}
