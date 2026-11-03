// 궁합지도(Gunghap Map) — 8개 분야 결정론적 등급 판정 규칙.
//
// [신통방통 궁합지도 개발 지시서 §3, 개발 승인 §2 대응]
// 8개 분야(연애/결혼/속궁합/성격/재물/사업/친구/가족) 각각에 대해,
// `gunghap-relation-fact.ts`가 계산한 FACT(S1~S6 + 십성 매트릭스 +
// 지지관계 매트릭스 + 음양조화)만을 근거로 "최상/상/중상/중/중하" 5단계
// 등급을 결정론적으로 산출한다.
//
// [절대 원칙 — 승인 문서 §2-5 그대로 인용]
// "근거가 없는 궁합 해석, 임의 점수, 가짜 통계는 생성하지 않는다." 이
// 파일의 모든 가중치는 (a) 전통 명리학에서 통용되는 일반 원칙(상생=호의적,
// 상극=긴장, 합=친화, 충형=갈등, 재성=돈/이성운, 관성=책임/질서, 식상=표현력,
// 인성=수용/보살핌, 비겁=동질감 — 귀인지도 PRD 및 guinji-v2 엔진에서 이미
// 채택된 동일 원칙)에 기반하며, (b) 반드시 FACT 필드(S1~S6, 십성그룹카운트,
// 지지관계카운트, 음양조화)로부터만 계산된다. 외부 통계·설문·임의 난수는
// 전혀 사용하지 않는다.
//
// [점수의 위치 — 사용자 비노출] `categoryScore`는 등급을 결정하기 위한
// **내부 계산값**이며, 화면에는 노출되지 않는다. 사용자에게는 오직
// `grade`(등급명)와 FACT 기반 서술(`gunghap-narrative.ts`가 생성)만
// 보여준다 — 승인 문서 §2-4 "사용자 화면에는 숫자 점수를 대표값으로
// 노출하지 않고... 등급과 FACT 기반 서술을 표시합니다" 그대로 반영.
//
// [8개 분야 구분 원칙] 각 분야는 서로 다른 FACT 가중치 조합을 사용해
// "서로 구분되는 판정 규칙"을 갖는다(승인 문서 §2-7). 아래 표로 요약:
//
//   분야      | 핵심 FACT 가중치
//   ----------|----------------------------------------------------
//   연애      | S1 상생/합(끌림) · 식상(매력·감정표현) · 음양조화
//   결혼      | S2 육합(안정) · S3 오행보완(생활보완) · 재성+관성 · 충형 감점 가중
//   속궁합    | 음양조화(최우선) · S2 일지관계(배우자궁) · 합계수
//   성격      | S1(기질 상생상극) · 비겁+인성(자아/수용) · 형충(갈등기질)
//   재물      | 재성 비중(최우선) · S3 오행보완(재물흐름)
//   사업      | 식상+관성(추진력·리더십) · S5 합충계수(협업 vs 충돌)
//   친구      | 비겁(동류의식, 최우선) · S5 합(의리) · 충 감점 완화(친구는 충돌에 관대)
//   가족      | 인성+관성(위계·돌봄) · S2/지지 합(안정) · 충형 감점 가중(가족은 갈등에 민감)
//
// [재사용] GRADES 컷오프는 `guinji-v2/relation.ts`에서 이미 검증된 표를
// 그대로 import해 재사용한다(등급 경계값을 이 파일에서 새로 정의하지 않음).

import { GRADES, type RuleTrace } from "../guinji-v2/relation";
import type { GunghapFactResult, BranchKindCounts } from "./gunghap-relation-fact";

export const GUNGHAP_CATEGORY_RULES_VERSION = "gunghap-category-rules-1.0.0";

export type GunghapCategoryId =
  | "love"
  | "marriage"
  | "intimacy"
  | "persona"
  | "wealth"
  | "business"
  | "friend"
  | "family";

/** 화면 표시용 고정 순서 — `gunghap_data.dart`의 `ghMajors` 8개와 1:1 대응(id 동일). */
export const GUNGHAP_CATEGORY_ORDER: readonly GunghapCategoryId[] = [
  "love",
  "marriage",
  "intimacy",
  "persona",
  "wealth",
  "business",
  "friend",
  "family",
];

export interface CategoryGradeResult {
  categoryId: GunghapCategoryId;
  /** [내부용, 비노출] 등급 산정을 위한 결정론적 계산값(0~100). */
  categoryScore: number;
  grade: string;
  gradeCode: string;
  /** 이 분야 판정에 실제로 사용된 FACT 근거(서술 생성기가 그대로 참조). */
  evidence: CategoryEvidence;
}

/** 분야별 판정에 사용된 FACT 요약 — narrative.ts가 "근거 없는 해석 생성"을
 * 하지 않도록, 서술 생성 시 반드시 이 구조체만을 참조하게 한다. */
export interface CategoryEvidence {
  s1Kind: RuleTrace["S1_일간오행"]["kind"];
  s1Direction: RuleTrace["S1_일간오행"]["direction"];
  s2Kind: RuleTrace["S2_일지관계"]["kind"];
  elementSupplyScore: number;
  hapCount: number;
  chungCount: number;
  hyungCount: number;
  tenGodGroupCounts: Record<string, number>;
  branchKindCounts: BranchKindCounts;
  yinYangHarmonious: boolean;
  /** 기반 귀인지도 V2 종합 점수/등급(참고용 — 분야별 점수의 "기본값"으로 일부 반영). */
  baseChemistryScore: number;
  baseGrade: string;
}

function buildEvidence(fact: GunghapFactResult): CategoryEvidence {
  const rt = fact.base.ruleTrace;
  return {
    s1Kind: rt.S1_일간오행.kind,
    s1Direction: rt.S1_일간오행.direction,
    s2Kind: rt.S2_일지관계.kind,
    elementSupplyScore: rt.S3_오행보완.score,
    hapCount: rt.S5_합충계수.hap,
    chungCount: rt.S5_합충계수.chung,
    hyungCount: rt.S5_합충계수.hyung,
    tenGodGroupCounts: fact.tenGodGroupCounts,
    branchKindCounts: fact.branchKindCounts,
    yinYangHarmonious: fact.yinYangHarmony.harmonious,
    baseChemistryScore: fact.base.chemistryScore,
    baseGrade: fact.base.grade,
  };
}

function clamp0to100(n: number): number {
  return Math.max(0, Math.min(100, n));
}

function gradeOf(score: number): { grade: string; gradeCode: string } {
  const entry = GRADES.find((g) => score >= g[0]) ?? GRADES[GRADES.length - 1];
  return { grade: entry[1], gradeCode: entry[2] };
}

/** S1 상생=가점, 상극=감점, 비화/무관=중립. 방향 무관(절대값 기준 — 분야 공통 보조 함수). */
function s1Bonus(ev: CategoryEvidence, saeng: number, geuk: number): number {
  if (ev.s1Kind === "상생") return saeng;
  if (ev.s1Kind === "상극") return -geuk;
  return 0;
}

/** S2 육합/삼합=가점, 충/형=감점(가중치는 분야별로 다름). */
function s2Bonus(ev: CategoryEvidence, hapPts: number, chungHyungPts: number): number {
  if (ev.s2Kind === "육합" || ev.s2Kind === "삼합") return hapPts;
  if (ev.s2Kind === "충" || ev.s2Kind === "형") return -chungHyungPts;
  if (ev.s2Kind === "파" || ev.s2Kind === "해") return -chungHyungPts * 0.5;
  return 0;
}

// ---------------- 분야별 점수식 ----------------
// 각 함수는 반드시 CategoryEvidence(=실제 FACT)만을 입력으로 받는다.
// 가중치 상수는 모듈 상단 주석의 "핵심 FACT 가중치" 표와 1:1 대응한다.

function scoreLove(ev: CategoryEvidence): number {
  const base = 45;
  const s1 = s1Bonus(ev, 14, 8); // 상생=끌림 강화, 상극=긴장으로 소폭 감점
  const s2 = s2Bonus(ev, 16, 10); // 합=설렘/인연, 충형=다툼
  const expression = (ev.tenGodGroupCounts["식상"] ?? 0) * 2; // 식상=감정표현·매력
  const yinYang = ev.yinYangHarmonious ? 8 : 0; // 음양조화=서로 끌리는 기본 조건
  const supply = ev.elementSupplyScore * 1.5;
  return clamp0to100(base + s1 + s2 + expression + yinYang + supply);
}

function scoreMarriage(ev: CategoryEvidence): number {
  const base = 42;
  const s1 = s1Bonus(ev, 10, 6);
  const s2 = s2Bonus(ev, 20, 16); // 결혼은 일지(배우자궁) 안정성 비중을 가장 높게
  const supply = ev.elementSupplyScore * 3; // 생활 전반을 보완하는 오행 흐름 중시
  const stability = ((ev.tenGodGroupCounts["재성"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0)) * 1.5;
  return clamp0to100(base + s1 + s2 + supply + stability);
}

function scoreIntimacy(ev: CategoryEvidence): number {
  const base = 48;
  const yinYang = ev.yinYangHarmonious ? 18 : -4; // 속궁합은 음양조화가 핵심 변수
  const s2 = s2Bonus(ev, 14, 8); // 일지(배우자궁) 관계
  const hap = ev.hapCount * 3;
  return clamp0to100(base + yinYang + s2 + hap);
}

function scorePersona(ev: CategoryEvidence): number {
  const base = 50;
  const s1 = s1Bonus(ev, 10, 10); // 성격은 상생=조화, 상극=기질 충돌로 동일 가중
  const selfGroups = ((ev.tenGodGroupCounts["비겁"] ?? 0) + (ev.tenGodGroupCounts["인성"] ?? 0)) * 1.5;
  const conflict = (ev.hyungCount + ev.chungCount) * -3; // 형충=기질 마찰
  return clamp0to100(base + s1 + selfGroups + conflict);
}

function scoreWealth(ev: CategoryEvidence): number {
  const base = 40;
  const wealthGroup = (ev.tenGodGroupCounts["재성"] ?? 0) * 6; // 재물 분야는 재성 비중 최우선
  const supply = ev.elementSupplyScore * 3;
  const s1 = s1Bonus(ev, 6, 6);
  return clamp0to100(base + wealthGroup + supply + s1);
}

function scoreBusiness(ev: CategoryEvidence): number {
  const base = 40;
  const driveGroup = ((ev.tenGodGroupCounts["식상"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0)) * 3; // 추진력·리더십
  const collab = ev.hapCount * 4; // 합=협업 시너지
  const conflict = (ev.chungCount + ev.hyungCount) * -4; // 충형=동업 리스크
  return clamp0to100(base + driveGroup + collab + conflict);
}

function scoreFriend(ev: CategoryEvidence): number {
  const base = 48;
  const peerGroup = (ev.tenGodGroupCounts["비겁"] ?? 0) * 5; // 동류의식(비겁)이 친구 분야 핵심
  const hap = ev.hapCount * 3; // 합=의리
  const conflict = (ev.chungCount + ev.hyungCount) * -2; // 친구 사이 충돌은 다른 분야보다 감점 완화
  return clamp0to100(base + peerGroup + hap + conflict);
}

function scoreFamily(ev: CategoryEvidence): number {
  const base = 44;
  const careGroup = ((ev.tenGodGroupCounts["인성"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0)) * 3; // 돌봄·위계
  const s2 = s2Bonus(ev, 12, 18); // 가족은 충형 감점을 가장 크게 반영(갈등에 민감)
  const branchHarmony = (ev.branchKindCounts["육합"] + ev.branchKindCounts["삼합"]) * 2;
  const branchConflict = (ev.branchKindCounts["충"] + ev.branchKindCounts["형"]) * -2;
  return clamp0to100(base + careGroup + s2 + branchHarmony + branchConflict);
}

const SCORERS: Record<GunghapCategoryId, (ev: CategoryEvidence) => number> = {
  love: scoreLove,
  marriage: scoreMarriage,
  intimacy: scoreIntimacy,
  persona: scorePersona,
  wealth: scoreWealth,
  business: scoreBusiness,
  friend: scoreFriend,
  family: scoreFamily,
};

/** 단일 분야 등급 판정. */
export function gradeCategory(fact: GunghapFactResult, categoryId: GunghapCategoryId): CategoryGradeResult {
  const evidence = buildEvidence(fact);
  const score = SCORERS[categoryId](evidence);
  const { grade, gradeCode } = gradeOf(score);
  return { categoryId, categoryScore: score, grade, gradeCode, evidence };
}

/** 8개 분야 전체 등급 판정(고정 순서, `GUNGHAP_CATEGORY_ORDER`). */
export function gradeAllCategories(fact: GunghapFactResult): CategoryGradeResult[] {
  return GUNGHAP_CATEGORY_ORDER.map((id) => gradeCategory(fact, id));
}
