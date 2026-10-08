// 귀인지도 V2 관계 엔진 (S1~S7 파이프라인) — TypeScript 포팅.
//
// [출처] Python 기준 소스 `guinji_v2_source/guinji_engine/relation.py`를
// 그대로 1:1 포팅한 것이다. 점수식/등급 컷오프/관계유형 판정 로직을
// 임의로 바꾸지 않았다. 두 사람의 표준 사주 데이터를 입력으로 받아,
// 관계 유형·점수·근거를 구조화해 반환한다. 해석 문장은 이 엔진에서
// 생성하지 않는다(해석 엔진이 담당). 결정적(deterministic).
//
// [검증] C01~C20 골든 벡터(`__fixtures__/python_golden_vectors.json`,
// Python 엔진 실제 실행 결과)와 1:1 대조하여 검증한다
// (`__tests__/relation.golden.test.ts` 참고).
//
// [중요 — 기존 파일과의 관계] 이 파일은 신규 V2 전용 파일이며, 기존
// `src/lib/guinji-relation-judger.ts`(12종 체계)를 수정·대체하지 않는다.
// API 라우트 연결은 골든 벡터 검증이 끝난 뒤 별도 단계에서 진행한다.

import * as C from "./constants";
import * as S from "./saju";
import type { PersonInput, NormalizedPerson, SajuSummary } from "./saju";
import type { BranchRelationKind, ElementKind, ElementDirection } from "./constants";

export const ENGINE_VERSION = "guinji-relation-1.0.0";
export const RULE_VERSION = "rules-1.0.0";

// 관계 유형 정의 (V2 설계안 §4·§6 확정, 6종)
export type GuinjiV2RelationType =
  | "CHEON_GWII"
  | "HAP"
  | "SANG_SAENG"
  | "SANG_GEUK"
  | "BI_HWA"
  | "CHUNG";

export const RELATION_TYPES: Record<GuinjiV2RelationType, { label: string; desc: string }> = {
  CHEON_GWII: { label: "천생귀인", desc: "타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계" },
  HAP: { label: "인연합", desc: "일지가 합을 이루어 자연스럽게 끌리고 정이 깊어지는 관계" },
  SANG_SAENG: { label: "상생동행", desc: "한쪽이 다른 쪽을 살리고 키워주는 상생의 관계" },
  SANG_GEUK: { label: "상극조율", desc: "서로 극하는 기운으로 긴장과 조율이 공존하는 관계" },
  BI_HWA: { label: "동류동반", desc: "같은 오행으로 결이 비슷해 편안하게 동행하는 관계" },
  CHUNG: { label: "충돌극복", desc: "일지가 충하여 부딪히지만 그만큼 성장을 만드는 관계" },
};

/**
 * [2026-?? 추가 — Flutter/API 4단계 6종 전환] V2 관계유형 6종의 정규
 * 순서(집계·필터·랭킹·카운트 이니셜라이즈용 단일 소스). 기존 12종 엔진의
 * `GUINJI_RELATION_TYPE_ORDER`(`guinji-relation-judger.ts`)를 대체한다 —
 * 호출부(relation-summary/route.ts, join/route.ts 등)가 12종을 다시
 * 하드코딩하지 않도록 이 파일에서 export한다. 순서 기준: CHEON_GWII를
 * 최상위로 두고, 나머지는 `GuinjiV2RelationType` 선언 순서와 동일.
 */
export const GUINJI_V2_RELATION_TYPE_ORDER: readonly GuinjiV2RelationType[] = [
  "CHEON_GWII",
  "HAP",
  "SANG_SAENG",
  "SANG_GEUK",
  "BI_HWA",
  "CHUNG",
];

/** [점수컷오프, 등급명, 등급코드] — 내림차순. */
export const GRADES: Array<[number, string, string]> = [
  [85, "최상", "S"],
  [70, "상", "A"],
  [55, "중상", "B"],
  [40, "중", "C"],
  [0, "중하", "D"],
];

// ---------------- S1. 일간 오행 관계 ----------------
export interface S1Result {
  elementA: string;
  elementB: string;
  kind: ElementKind;
  direction: ElementDirection;
}

export function s1DayMasterRelation(a: NormalizedPerson, b: NormalizedPerson): S1Result {
  const ea = C.STEM_ELEMENT[S.dayMaster(a)];
  const eb = C.STEM_ELEMENT[S.dayMaster(b)];
  const { kind, direction } = C.elementRelation(ea, eb);
  return { elementA: ea, elementB: eb, kind, direction };
}

// ---------------- S2. 일지 관계 ----------------
export interface S2Result {
  branchA: string;
  branchB: string;
  kind: BranchRelationKind;
  desc: string;
}

export function s2DayBranchRelation(a: NormalizedPerson, b: NormalizedPerson): S2Result {
  const ba = S.dayBranch(a);
  const bb = S.dayBranch(b);
  const { kind, desc } = C.branchRelation(ba, bb);
  return { branchA: ba, branchB: bb, kind, desc };
}

// ---------------- S3. 오행 보완도 ----------------
export interface S3Result {
  lackingA: string[];
  lackingB: string[];
  supplyAtoB: number;
  supplyBtoA: number;
  score: number;
}

/** A가 부족한 오행을 B가 얼마나 채워주는가(0~5). 양방향 평균. */
export function s3ElementSupply(a: NormalizedPerson, b: NormalizedPerson): S3Result {
  const ca = S.elementCounts(a.pillars);
  const cb = S.elementCounts(b.pillars);
  const la = new Set(S.lacking(ca));
  const lb = new Set(S.lacking(cb));
  let supplyAb = 0; // B가 A의 부족을 채움
  for (const e of la) if ((cb[e] ?? 0) >= 2) supplyAb++;
  let supplyBa = 0; // A가 B의 부족을 채움
  for (const e of lb) if ((ca[e] ?? 0) >= 2) supplyBa++;
  const raw = supplyAb + supplyBa;
  const score = Math.min(raw, 5);
  return {
    lackingA: Array.from(la).sort(),
    lackingB: Array.from(lb).sort(),
    supplyAtoB: supplyBa,
    supplyBtoA: supplyAb,
    score,
  };
}

// ---------------- S4. 십성 상호작용 ----------------
export interface S4Result {
  bIsToA: string;
  aIsToB: string;
  groupBIsToA: string;
  groupAIsToB: string;
}

export function s4TenGods(a: NormalizedPerson, b: NormalizedPerson): S4Result {
  const aToB = C.tenGod(S.dayMaster(a), S.dayMaster(b)); // B가 A에게 어떤 존재인가
  const bToA = C.tenGod(S.dayMaster(b), S.dayMaster(a));
  return {
    bIsToA: aToB,
    aIsToB: bToA,
    groupBIsToA: C.TEN_GOD_GROUP[aToB],
    groupAIsToB: C.TEN_GOD_GROUP[bToA],
  };
}

// ---------------- S5. 합충 계수 ----------------
export interface S5Result {
  hap: number;
  chung: number;
  hyung: number;
  pairs: Array<[string, string, string]>;
}

export function s5HapChungCount(a: NormalizedPerson, b: NormalizedPerson): S5Result {
  const ba = S.allBranches(a);
  const bb = S.allBranches(b);
  let hap = 0;
  let chung = 0;
  let hyung = 0;
  const pairs: Array<[string, string, string]> = [];
  for (const x of ba) {
    for (const y of bb) {
      if (C.isYukhap(x, y) || C.samhapElement(x, y)) {
        hap += 1;
        pairs.push([x, y, "합"]);
      }
      if (C.isChung(x, y)) {
        chung += 1;
        pairs.push([x, y, "충"]);
      } else if (C.isHyung(x, y)) {
        hyung += 1;
        pairs.push([x, y, "형"]);
      }
    }
  }
  return { hap, chung, hyung, pairs };
}

// ---------------- S6. 점수화 ----------------
export interface S6Result {
  score: number;
  grade: string;
  gradeCode: string;
  breakdown: {
    일간기본: number;
    일지: number;
    오행보완: number;
    합가점: number;
    십성보정: number;
    충형감점: number;
  };
}

const S1_BASE: Record<string, number> = { 상생: 30, 비화: 22, 상극: 12, 무관: 16 };
const S2_BRANCH_PTS: Record<string, number> = { 육합: 25, 삼합: 22, 무관: 15, 파: 10, 해: 8, 형: 5, 충: 0 };

export function s6Score(s1: S1Result, s2: S2Result, s3: S3Result, s4: S4Result, s5: S5Result): S6Result {
  const base = S1_BASE[s1.kind];
  const branchPts = S2_BRANCH_PTS[s2.kind];
  const supplyPts = s3.score * 4; // 0~20
  const hapPts = Math.min(s5.hap, 4) * 4; // 0~16
  const chungPen = Math.min(s5.chung + s5.hyung, 4) * 5; // 0~20 감점
  // 십성 보정: 재성/정관은 관계 안정에 소폭 가점
  let godPts = 0;
  for (const g of [s4.groupBIsToA, s4.groupAIsToB]) {
    if (g === "재성" || g === "관성") godPts += 3;
    else if (g === "식상") godPts += 1;
  }
  let total = base + branchPts + supplyPts + hapPts + godPts - chungPen;
  total = Math.max(0, Math.min(100, total));
  const gradeEntry = GRADES.find((g) => total >= g[0]) ?? GRADES[GRADES.length - 1];
  return {
    score: total,
    grade: gradeEntry[1],
    gradeCode: gradeEntry[2],
    breakdown: {
      일간기본: base,
      일지: branchPts,
      오행보완: supplyPts,
      합가점: hapPts,
      십성보정: godPts,
      충형감점: -chungPen,
    },
  };
}

// ---------------- 관계 유형 판정 ----------------
export function decideType(s1: S1Result, s2: S2Result, score: number): GuinjiV2RelationType {
  if (score >= 82 && s1.kind === "상생" && (s2.kind === "육합" || s2.kind === "삼합")) {
    return "CHEON_GWII";
  }
  if (s2.kind === "육합" || s2.kind === "삼합") return "HAP";
  if (s1.kind === "상생") return "SANG_SAENG";
  if (s1.kind === "상극") return "SANG_GEUK";
  if (s1.kind === "비화") return "BI_HWA";
  if (s2.kind === "충") return "CHUNG";
  return "BI_HWA";
}

// ---------------- S7. 근거 기록 + 전체 조립 ----------------

/**
 * Python `json.dumps(obj, ensure_ascii=False, sort_keys=True)`와 동일한
 * 직렬화(키 알파벳 정렬, 기본 구분자 ", "/": ", 유니코드 그대로)를
 * 재현한다. `resultId`(입력 해시 기반)를 Python과 동일하게 생성하기
 * 위해 반드시 필요 — 일반 `JSON.stringify`는 키 순서를 보존하므로
 * Python의 정렬 동작과 다르다.
 */
function pyCanonicalJson(value: unknown): string {
  if (value === null || value === undefined) return "null";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number" || typeof value === "boolean") return JSON.stringify(value);
  if (Array.isArray(value)) {
    return "[" + value.map((v) => pyCanonicalJson(v)).join(", ") + "]";
  }
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj).sort();
    return (
      "{" +
      keys.map((k) => `${JSON.stringify(k)}: ${pyCanonicalJson(obj[k])}`).join(", ") +
      "}"
    );
  }
  throw new Error(`pyCanonicalJson: unsupported value type ${typeof value}`);
}

async function sha1Hex(input: string): Promise<string> {
  // Node.js 런타임(crypto) 사용. Edge 런타임에서는 Web Crypto로 대체 필요
  // (현재 Guinji API 라우트는 Node 런타임을 사용하므로 이 구현으로 충분).
  const { createHash } = await import("crypto");
  return createHash("sha1").update(input, "utf-8").digest("hex");
}

/** pillars를 Python과 동일한 JSON 표현(튜플→배열, None→null)으로 변환. */
function pillarsToPlain(pillars: NormalizedPerson["pillars"]): Record<string, [string, string] | null> {
  const out: Record<string, [string, string] | null> = {};
  for (const k of S.PILLAR_KEYS) {
    const v = pillars[k];
    out[k] = v ? [v[0], v[1]] : null;
  }
  return out;
}

async function resultId(owner: NormalizedPerson, member: NormalizedPerson): Promise<string> {
  const key = pyCanonicalJson({
    a: pillarsToPlain(owner.pillars),
    b: pillarsToPlain(member.pillars),
    e: ENGINE_VERSION,
    r: RULE_VERSION,
  });
  const hash = await sha1Hex(key);
  return "gr_" + hash.slice(0, 16);
}

export interface RuleTrace {
  S1_일간오행: S1Result;
  S2_일지관계: S2Result;
  S3_오행보완: S3Result;
  S4_십성: S4Result;
  S5_합충계수: S5Result;
  S6_점수: S6Result;
}

export interface GuinjiV2RelationResult {
  resultId: string;
  engineVersion: string;
  ruleVersion: string;
  relationType: GuinjiV2RelationType;
  relationTypeLabel: string;
  relationTypeDesc: string;
  chemistryScore: number;
  grade: string;
  gradeCode: string;
  owner: SajuSummary;
  member: SajuSummary;
  ruleTrace: RuleTrace;
}

/** 두 사람의 사주를 받아 관계 결과(구조화)를 반환한다. */
export async function computeRelation(
  ownerInput: PersonInput,
  memberInput: PersonInput,
): Promise<GuinjiV2RelationResult> {
  const a = S.normalize(ownerInput);
  const b = S.normalize(memberInput);

  const s1 = s1DayMasterRelation(a, b);
  const s2 = s2DayBranchRelation(a, b);
  const s3 = s3ElementSupply(a, b);
  const s4 = s4TenGods(a, b);
  const s5 = s5HapChungCount(a, b);
  const s6 = s6Score(s1, s2, s3, s4, s5);
  const rtype = decideType(s1, s2, s6.score);

  const ruleTrace: RuleTrace = {
    S1_일간오행: s1,
    S2_일지관계: s2,
    S3_오행보완: s3,
    S4_십성: s4,
    S5_합충계수: s5,
    S6_점수: s6,
  };

  return {
    resultId: await resultId(a, b),
    engineVersion: ENGINE_VERSION,
    ruleVersion: RULE_VERSION,
    relationType: rtype,
    relationTypeLabel: RELATION_TYPES[rtype].label,
    relationTypeDesc: RELATION_TYPES[rtype].desc,
    chemistryScore: s6.score,
    grade: s6.grade,
    gradeCode: s6.gradeCode,
    owner: S.summarize(a),
    member: S.summarize(b),
    ruleTrace,
  };
}
