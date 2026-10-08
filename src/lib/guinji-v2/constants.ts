// 귀인지도 V2 관계 엔진 — 사주 상수 정의 (천간/지지/오행/합충형해파/십성).
//
// [출처] Python 기준 소스 `guinji_v2_source/guinji_engine/constants.py`를
// 그대로 1:1 포팅한 것이다. 상수 값·함수 로직을 임의로 바꾸지 않았다.
// 이 모듈은 순수 상수와 판정 함수만 담는다(외부 의존성 없음) — Python
// 원본과 동일한 설계 원칙.
//
// [중요] 이 파일은 신규 V2 전용 파일이며, 기존
// `src/lib/guinji-relation-judger.ts`(12종 체계, GAN_ELEMENT 등 한자 키
// 고정표)를 수정하거나 대체하지 않는다. V2 엔진은 Python 원본과 동일하게
// "한글 1글자" 공간(갑/을/병... , 자/축/인...)에서 동작한다 — 한자 변환은
// 추후 API 계약 통합 단계에서 별도로 처리한다.

export type ElementKind = "상생" | "상극" | "비화" | "무관";
export type ElementDirection = "out" | "in" | null;

// ---------------- 천간 (Heavenly Stems, 10) ----------------
export const STEMS = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"] as const;
export type Stem = (typeof STEMS)[number];

export const STEM_HANJA: Record<string, string> = {
  갑: "甲", 을: "乙", 병: "丙", 정: "丁", 무: "戊",
  기: "己", 경: "庚", 신: "辛", 임: "壬", 계: "癸",
};

export const STEM_ELEMENT: Record<string, string> = {
  갑: "목", 을: "목", 병: "화", 정: "화", 무: "토",
  기: "토", 경: "금", 신: "금", 임: "수", 계: "수",
};

export const STEM_YANG: Record<string, boolean> = {
  갑: true, 을: false, 병: true, 정: false, 무: true,
  기: false, 경: true, 신: false, 임: true, 계: false,
};

// ---------------- 지지 (Earthly Branches, 12) ----------------
export const BRANCHES = [
  "자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해",
] as const;
export type Branch = (typeof BRANCHES)[number];

export const BRANCH_HANJA: Record<string, string> = {
  자: "子", 축: "丑", 인: "寅", 묘: "卯", 진: "辰", 사: "巳",
  오: "午", 미: "未", 신: "申", 유: "酉", 술: "戌", 해: "亥",
};

export const BRANCH_ELEMENT: Record<string, string> = {
  자: "수", 축: "토", 인: "목", 묘: "목", 진: "토", 사: "화",
  오: "화", 미: "토", 신: "금", 유: "금", 술: "토", 해: "수",
};

export const BRANCH_YANG: Record<string, boolean> = {
  자: true, 축: false, 인: true, 묘: false, 진: true, 사: false,
  오: true, 미: false, 신: true, 유: false, 술: true, 해: false,
};

// ---------------- 오행 ----------------
export const ELEMENTS = ["목", "화", "토", "금", "수"] as const;
export type Element = (typeof ELEMENTS)[number];

export const ELEMENT_HANJA: Record<string, string> = {
  목: "木", 화: "火", 토: "土", 금: "金", 수: "水",
};

/** 상생: key가 value를 생한다. */
export const GENERATES: Record<string, string> = { 목: "화", 화: "토", 토: "금", 금: "수", 수: "목" };
/** 상극: key가 value를 극한다. */
export const CONTROLS: Record<string, string> = { 목: "토", 토: "수", 수: "화", 화: "금", 금: "목" };

export function generates(a: string, b: string): boolean {
  return GENERATES[a] === b;
}

export function controls(a: string, b: string): boolean {
  return CONTROLS[a] === b;
}

/**
 * a,b 오행 관계를 (종류, 방향)으로 반환.
 * 종류: 상생 / 상극 / 비화 / 무관
 * 방향: 'out' = a가 b에게 작용, 'in' = b가 a에게 작용, null = 대칭
 */
export function elementRelation(a: string, b: string): { kind: ElementKind; direction: ElementDirection } {
  if (a === b) return { kind: "비화", direction: null };
  if (generates(a, b)) return { kind: "상생", direction: "out" };
  if (generates(b, a)) return { kind: "상생", direction: "in" };
  if (controls(a, b)) return { kind: "상극", direction: "out" };
  if (controls(b, a)) return { kind: "상극", direction: "in" };
  return { kind: "무관", direction: null };
}

// ---------------- 지지 관계 ----------------
export const YUKHAP: Array<[string, string]> = [
  ["자", "축"], ["인", "해"], ["묘", "술"], ["진", "유"], ["사", "신"], ["오", "미"],
];

export const SAMHAP_GROUPS: Record<string, [string, string, string]> = {
  화: ["인", "오", "술"],
  수: ["신", "자", "진"],
  목: ["해", "묘", "미"],
  금: ["사", "유", "축"],
};

export const CHUNG: Array<[string, string]> = [
  ["자", "오"], ["축", "미"], ["인", "신"], ["묘", "유"], ["진", "술"], ["사", "해"],
];

export const HYUNG: Array<[string, string]> = [
  ["인", "사"], ["사", "신"], ["인", "신"],
  ["축", "술"], ["술", "미"], ["축", "미"], ["자", "묘"],
];

export const HAE: Array<[string, string]> = [
  ["자", "미"], ["축", "오"], ["인", "해"], ["묘", "신"], ["진", "유"], ["사", "술"],
];

export const PA: Array<[string, string]> = [
  ["자", "유"], ["축", "진"], ["인", "해"], ["묘", "오"], ["사", "신"], ["술", "미"],
];

function pairMatch(pairs: Array<[string, string]>, x: string, y: string): boolean {
  return pairs.some(([a, b]) => (a === x && b === y) || (a === y && b === x));
}

export function isYukhap(a: string, b: string): boolean { return pairMatch(YUKHAP, a, b); }
export function isChung(a: string, b: string): boolean { return pairMatch(CHUNG, a, b); }
export function isHyung(a: string, b: string): boolean { return pairMatch(HYUNG, a, b); }
export function isHae(a: string, b: string): boolean { return pairMatch(HAE, a, b); }
export function isPa(a: string, b: string): boolean { return pairMatch(PA, a, b); }

/** 두 지지가 같은 삼합국에 속하면 그 국의 오행, 아니면 null. */
export function samhapElement(a: string, b: string): string | null {
  for (const [el, grp] of Object.entries(SAMHAP_GROUPS)) {
    if (grp.includes(a) && grp.includes(b) && a !== b) return el;
  }
  return null;
}

export type BranchRelationKind = "육합" | "삼합" | "충" | "형" | "파" | "해" | "무관";

/** 두 지지의 관계를 우선순위로 판정해 (종류, 설명) 반환. */
export function branchRelation(
  a: string | null,
  b: string | null,
): { kind: BranchRelationKind; desc: string } {
  if (a === null || b === null) return { kind: "무관", desc: "시주 미상" };
  if (isYukhap(a, b)) return { kind: "육합", desc: "육합" };
  const se = samhapElement(a, b);
  if (se) return { kind: "삼합", desc: `삼합(${se}국)` };
  if (isChung(a, b)) return { kind: "충", desc: "충" };
  if (isHyung(a, b)) return { kind: "형", desc: "형" };
  if (isPa(a, b)) return { kind: "파", desc: "파" };
  if (isHae(a, b)) return { kind: "해", desc: "해" };
  return { kind: "무관", desc: "특별한 합충 없음" };
}

// ---------------- 십성 ----------------
export function tenGod(dayStem: string, otherStem: string): string {
  const me = STEM_ELEMENT[dayStem];
  const other = STEM_ELEMENT[otherStem];
  const same = STEM_YANG[dayStem] === STEM_YANG[otherStem];
  if (me === other) return same ? "비견" : "겁재";
  if (generates(me, other)) return same ? "식신" : "상관";
  if (controls(me, other)) return same ? "편재" : "정재";
  if (controls(other, me)) return same ? "편관" : "정관";
  if (generates(other, me)) return same ? "편인" : "정인";
  return "무관";
}

export const TEN_GOD_GROUP: Record<string, string> = {
  비견: "비겁", 겁재: "비겁", 식신: "식상", 상관: "식상",
  편재: "재성", 정재: "재성", 편관: "관성", 정관: "관성",
  편인: "인성", 정인: "인성",
};
