// [관상·손금 후속 개발 — 전수 검수 보고서 기준] 손금 판정 레이어.
// face-judgment.ts / saju-judgment.ts와 동일한 3단 분리 원칙을 따른다.
//
//   ① 관찰 레이어(route.ts, completeVisionJson) — 사진+손 방향 → PalmObserved
//      (선택지 강제 JSON). Vision LLM은 "사진에서 무엇이 보이는가"만 답한다.
//   ② 판정 레이어(이 파일) — PalmObserved → PalmJudgment. 주요 손금(생명선/
//      두뇌선/감정선/운명선)과 보조 손금(태양선/수성선/결혼선)의 형태·길이·
//      깊이·분기 조합을 결정론적 룩업테이블로 해석한다(LLM 비개입).
//   ③ 표현 레이어(LLM, route.ts) — 이 파일이 만든 JSON만 받아서 문장을 쓴다.
//
// [좌우손 반영] 전통 수상학에서 왼손은 선천(타고난 기질), 오른손은 후천(현재
// 노력/변화)을 본다는 해석 관습이 있다. 이 구현은 "hand"를 판정 로직에 직접
// 반영해 동일한 선 모양이라도 왼손/오른손에 따라 hook 문구의 관점이 달라지게
// 한다(거짓으로 다른 결과를 꾸며내는 것이 아니라, 관찰값은 동일하게 쓰되 해석의
// "시제/관점"만 전통 관습에 따라 달리함 — 사용자 요청 2번: hand를 분석에 반영).

export type PalmHand = "right" | "left";
export type PalmGrade = "good" | "neutral" | "caution";

export interface PalmVerdictEntry {
  grade: PalmGrade;
  primary_evidence: string;
  hook: string;
}

// ── ① 관찰 레이어가 채워야 하는 입력 스키마(선택지 강제) ──
export type LineLength = "긺" | "보통" | "짧음";
export type LineDepth = "깊음" | "보통" | "옅음";
export type LineShape = "직선형" | "곡선형" | "끊어짐" | "갈라짐(지선)";
export type LinePresence = "뚜렷함" | "흐릿함" | "없음";

export interface PalmObserved {
  valid: boolean;
  invalidReason: string | null;
  hand: PalmHand;
  // 주요 손금(4대선)
  majorLines: {
    생명선: { length: LineLength; depth: LineDepth; shape: LineShape };
    두뇌선: { length: LineLength; depth: LineDepth; shape: LineShape };
    감정선: { length: LineLength; depth: LineDepth; shape: LineShape };
    운명선: { presence: LinePresence; shape: LineShape };
  };
  // 보조 손금
  minorLines: {
    태양선: { presence: LinePresence };
    수성선: { presence: LinePresence };
    결혼선: { presence: LinePresence; count: "없음" | "1개" | "2개 이상" };
  };
}

export interface PalmJudgment {
  hand: PalmHand;
  hand_interpretation_note: string;
  major_line_grade: Record<"생명선" | "두뇌선" | "감정선" | "운명선", PalmGrade>;
  minor_line_summary: string;
  verdict: {
    wealth: PalmVerdictEntry;
    relation: PalmVerdictEntry;
    career: PalmVerdictEntry;
    health: PalmVerdictEntry;
  };
}

function lengthScore(v: LineLength): number {
  return v === "긺" ? 1 : v === "보통" ? 0 : -1;
}
function depthScore(v: LineDepth): number {
  return v === "깊음" ? 1 : v === "보통" ? 0 : -1;
}
function presenceScore(v: LinePresence): number {
  return v === "뚜렷함" ? 1 : v === "흐릿함" ? 0 : -1;
}

function judgeMajorLines(m: PalmObserved["majorLines"]): PalmJudgment["major_line_grade"] {
  const lifeScore = lengthScore(m.생명선.length) + depthScore(m.생명선.depth);
  const 생명선: PalmGrade = lifeScore >= 1 ? "good" : lifeScore <= -1 ? "caution" : "neutral";

  const headScore = lengthScore(m.두뇌선.length) + depthScore(m.두뇌선.depth);
  const 두뇌선: PalmGrade =
    m.두뇌선.shape === "끊어짐" ? "caution" : headScore >= 1 ? "good" : headScore <= -1 ? "caution" : "neutral";

  const heartScore = depthScore(m.감정선.depth);
  const 감정선: PalmGrade =
    m.감정선.shape === "끊어짐" ? "caution" : heartScore >= 1 ? "good" : "neutral";

  const 운명선: PalmGrade =
    m.운명선.presence === "뚜렷함" ? "good" : m.운명선.presence === "없음" ? "neutral" : "neutral";

  return { 생명선, 두뇌선, 감정선, 운명선 };
}

function handInterpretationNote(hand: PalmHand): string {
  // 전통 수상학 해석 관습: 왼손=선천(타고난 기질), 오른손=후천(현재 노력/변화).
  // 사실 단정이 아니라 "참고용 해석 관점"임을 명시한다(표현 레이어 LLM이
  // 과장하지 않도록 판정 레이어에서부터 톤을 제한).
  return hand === "left"
    ? "왼손 기준 — 타고난 기질과 바탕에 가까운 경향을 참고로 해석합니다."
    : "오른손 기준 — 현재의 노력과 최근 흐름에 가까운 경향을 참고로 해석합니다.";
}

/**
 * PalmObserved(관찰값)만 입력받아 PalmJudgment(판정)를 결정론적으로 산출한다.
 * LLM을 호출하지 않으며, 동일 입력(hand 포함)에는 항상 동일 출력을 반환한다.
 */
export function buildPalmJudgment(observed: PalmObserved): PalmJudgment {
  const hand = observed.hand;
  const major_line_grade = judgeMajorLines(observed.majorLines);
  const { minorLines } = observed;

  const minor_line_summary = `태양선 ${minorLines.태양선.presence} · 수성선 ${minorLines.수성선.presence} · 결혼선 ${minorLines.결혼선.count}`;

  // ── 재물: 운명선 + 태양선(재물/명예선으로도 불림) 조합 ──
  const sunScore = presenceScore(minorLines.태양선.presence);
  const wealth: PalmVerdictEntry =
    major_line_grade.운명선 === "good" && sunScore >= 0
      ? { grade: "good", primary_evidence: `운명선 ${observed.majorLines.운명선.presence} · 태양선 ${minorLines.태양선.presence}`, hook: "꾸준한 흐름이 재물로 이어지는 기운" }
      : major_line_grade.운명선 === "caution" && sunScore < 0
        ? { grade: "caution", primary_evidence: `운명선 ${observed.majorLines.운명선.presence} · 태양선 ${minorLines.태양선.presence}`, hook: "재물의 흐름을 계획적으로 관리할 필요가 있음" }
        : { grade: "neutral", primary_evidence: `운명선 ${observed.majorLines.운명선.presence}`, hook: "무리하지 않는 선에서 꾸준히 쌓아가는 편" };

  // ── 애정: 감정선 + 결혼선 조합 ──
  const relation: PalmVerdictEntry =
    major_line_grade.감정선 === "good" && minorLines.결혼선.presence !== "없음"
      ? { grade: "good", primary_evidence: `감정선 ${observed.majorLines.감정선.depth} · 결혼선 ${minorLines.결혼선.count}`, hook: "감정 표현이 솔직해 좋은 인연으로 이어지는 편" }
      : major_line_grade.감정선 === "caution"
        ? { grade: "caution", primary_evidence: `감정선 형태(${observed.majorLines.감정선.shape})`, hook: "관계에서 감정을 조금 더 꺼내 보여도 좋은 시기" }
        : { grade: "neutral", primary_evidence: `감정선 ${observed.majorLines.감정선.depth}`, hook: "관계의 속도를 스스로 조절하는 편" };

  // ── 직업: 두뇌선 + 수성선(사업/소통선) 조합 ──
  const mercuryScore = presenceScore(minorLines.수성선.presence);
  const career: PalmVerdictEntry =
    major_line_grade.두뇌선 === "good" || mercuryScore > 0
      ? { grade: "good", primary_evidence: `두뇌선 ${observed.majorLines.두뇌선.length} · 수성선 ${minorLines.수성선.presence}`, hook: "생각을 실행으로 옮기는 힘이 좋은 편" }
      : major_line_grade.두뇌선 === "caution"
        ? { grade: "caution", primary_evidence: `두뇌선 형태(${observed.majorLines.두뇌선.shape})`, hook: "중요한 결정은 서두르지 않는 편이 유리함" }
        : { grade: "neutral", primary_evidence: `두뇌선 ${observed.majorLines.두뇌선.length}`, hook: "꾸준함으로 성과를 만들어가는 편" };

  // ── 건강: 생명선 중심 ──
  const health: PalmVerdictEntry =
    major_line_grade.생명선 === "good"
      ? { grade: "good", primary_evidence: `생명선 ${observed.majorLines.생명선.length} · ${observed.majorLines.생명선.depth}`, hook: "전반적인 체력과 회복력이 좋은 편" }
      : major_line_grade.생명선 === "caution"
        ? { grade: "caution", primary_evidence: `생명선 ${observed.majorLines.생명선.length} · ${observed.majorLines.생명선.depth}`, hook: "휴식과 회복의 리듬을 챙길 필요가 있음" }
        : { grade: "neutral", primary_evidence: `생명선 ${observed.majorLines.생명선.length}`, hook: "큰 기복 없이 안정적으로 이어지는 흐름" };

  return {
    hand,
    hand_interpretation_note: handInterpretationNote(hand),
    major_line_grade,
    minor_line_summary,
    verdict: { wealth, relation, career, health },
  };
}
