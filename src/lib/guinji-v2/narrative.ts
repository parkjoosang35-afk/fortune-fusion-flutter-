// 귀인지도 V2 — ruleTrace(S1~S6 구조화 데이터) → ohaengEvidence{mine,other,reason}
// 변환기(해석 문장 생성).
//
// [배경] 기존 12종 엔진(`guinji-relation-judger.ts`)의 `judgeGuinjiRelation()`은
// `ohaengEvidence: {mine, other, reason, otherDominantCategory, breakdown}`
// 구조를 반환했고, Flutter `guinji_person.dart`의 `fromServerJson()`이 이
// 구조 중 `other`(오행 카운트, 한글 목/화/토/금/수 키 → 화면 표시용 ohaeng
// 아이콘 결정)와 `reason`(사람이 읽는 한 줄 설명 → `person.note`에 그대로
// 노출)을 사용한다.
//
// V2 엔진(`relation.ts`)은 `ohaengEvidence`가 아니라 구조화된 `ruleTrace`
// (S1~S6 각 단계의 원시 계산 결과)를 반환하도록 설계되었다 — 사람이 읽는
// 문장을 엔진이 직접 만들지 않는다("해석 문장은 이 엔진에서 생성하지
// 않는다" relation.ts 주석 참고). 이 파일이 그 "해석" 역할을 담당한다.
//
// [절대 준수 — 단순 빈 문자열/대충 만든 문장 금지] `reason`은 반드시
// S1~S6 실제 계산값(일간오행관계·일지관계·오행보완·십성·합충계수·점수)을
// 반영한, 항상 0글자 이상인 결정적(deterministic) 한국어 문장이어야
// 한다. 동일 입력 → 항상 동일 reason(엔진 자체가 결정적이므로 이 변환도
// 결정적으로 유지).
//
// [호환성] 반환 타입은 기존 `ohaengEvidence` 계약과 완전히 같은 모양
// (`{mine, other, reason}` 최소 필드 + 참고용 부가 필드)이다 — Flutter
// 소비 코드(`guinji_person.dart`)를 전혀 수정하지 않고도 그대로 읽힌다.
// `mine`/`other`의 키(목/화/토/금/수)도 기존과 동일하다(V2
// `SajuSummary.elementCounts`가 이미 이 포맷).

import type { GuinjiV2RelationResult, RuleTrace } from "./relation";

/** 기존 12종 엔진 `ohaengEvidence`와 호환되는 반환 타입. */
export interface GuinjiOhaengEvidence {
  /** 나(owner)의 오행 카운트(목/화/토/금/수). */
  mine: Record<string, number>;
  /** 상대(member)의 오행 카운트(목/화/토/금/수). */
  other: Record<string, number>;
  /** 사람이 읽는 한국어 설명 — Flutter `person.note`에 그대로 노출된다. */
  reason: string;
  /** [참고용] V2 엔진의 전체 S1~S6 원시 데이터를 보존 — 기존 필드는 아니지만
   * 투명성을 위해 함께 저장한다(소비 측은 optional로 다뤄야 함, 기존
   * 레코드에는 이 필드가 없음). */
  ruleTrace: RuleTrace;
  /** [참고용] V2 관계유형 라벨/점수/등급 — 디버깅/투명성용. */
  relationTypeLabel: string;
  grade: string;
  gradeCode: string;
}

const DIR_LABEL: Record<string, string> = { out: "→", in: "←" };

/** S1(일간오행관계) 설명 문장. */
function describeS1(s1: RuleTrace["S1_일간오행"]): string {
  const arrow = s1.direction ? ` ${DIR_LABEL[s1.direction]} ` : "";
  switch (s1.kind) {
    case "상생":
      return s1.direction === "out"
        ? `일간 오행이 나(${s1.elementA})→상대(${s1.elementB})로 생(生)하는 상생관계`
        : `일간 오행이 상대(${s1.elementB})→나(${s1.elementA})로 생(生)하는 상생관계`;
    case "상극":
      return s1.direction === "out"
        ? `일간 오행이 나(${s1.elementA})→상대(${s1.elementB})를 극(剋)하는 상극관계`
        : `일간 오행이 상대(${s1.elementB})→나(${s1.elementA})를 극(剋)하는 상극관계`;
    case "비화":
      return `일간 오행이 둘 다 ${s1.elementA}(으)로 같아 비화(동류) 관계`;
    default:
      return `일간 오행(${s1.elementA}${arrow}${s1.elementB}) 간 특별한 생극관계 없음`;
  }
}

/** S2(일지관계) 설명 문장. */
function describeS2(s2: RuleTrace["S2_일지관계"]): string {
  if (s2.kind === "무관") return "일지(日支)는 특별한 합충 없음";
  return `일지는 ${s2.desc}`;
}

/** S3(오행보완도) 설명 문장. */
function describeS3(s3: RuleTrace["S3_오행보완"]): string {
  if (s3.score <= 0) return "오행 보완은 거의 없음";
  const parts: string[] = [];
  if (s3.supplyAtoB > 0) parts.push(`내가 상대의 부족오행을 ${s3.supplyAtoB}개 보완`);
  if (s3.supplyBtoA > 0) parts.push(`상대가 내 부족오행을 ${s3.supplyBtoA}개 보완`);
  const detail = parts.length > 0 ? `(${parts.join(", ")})` : "";
  return `오행보완 지수 ${s3.score}/5${detail}`;
}

/** S4(십성) 설명 문장 — 상대가 나에게 어떤 존재인지 중심으로 서술. */
function describeS4(s4: RuleTrace["S4_십성"]): string {
  return `상대는 나에게 '${s4.bIsToA}'(${s4.groupBIsToA}), 나는 상대에게 '${s4.aIsToB}'(${s4.groupAIsToB})`;
}

/** S5(합충계수) 설명 문장. */
function describeS5(s5: RuleTrace["S5_합충계수"]): string {
  const bits: string[] = [];
  bits.push(`합 ${s5.hap}건`);
  bits.push(`충 ${s5.chung}건`);
  if (s5.hyung > 0) bits.push(`형 ${s5.hyung}건`);
  return bits.join(" · ");
}

/**
 * V2 관계 판정 결과(`computeRelation()` 반환값)로부터 사람이 읽을 수 있는
 * `ohaengEvidence{mine,other,reason}`을 생성한다. 결정적(deterministic) —
 * 동일 입력이면 항상 동일 문장을 만든다.
 */
export function buildOhaengEvidence(result: GuinjiV2RelationResult): GuinjiOhaengEvidence {
  const { ruleTrace } = result;

  const sentenceParts = [
    describeS1(ruleTrace.S1_일간오행),
    describeS2(ruleTrace.S2_일지관계),
    describeS3(ruleTrace.S3_오행보완),
    describeS4(ruleTrace.S4_십성),
    describeS5(ruleTrace.S5_합충계수),
    `종합 ${result.chemistryScore}점(${result.grade}등급) · ${result.relationTypeLabel}`,
  ];
  const reason = sentenceParts.filter((s) => s && s.length > 0).join(" · ");

  return {
    mine: result.owner.elementCounts,
    other: result.member.elementCounts,
    reason,
    ruleTrace,
    relationTypeLabel: result.relationTypeLabel,
    grade: result.grade,
    gradeCode: result.gradeCode,
  };
}
