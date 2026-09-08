// [2026-11, "같은 귀인 4명이 다 똑같다" 버그 수정 — 핵심 신설 파일]
//
// 사용자 격노 지적 원문: "귀인으로 돼어있는 사람이 4명이면 다 사주 관계
// 내용이 똑같아 너 사기치냐? ... 어뷰징 없이 같은 귀인이라도 다 내용이
// 틀리고 그리고 글을 좀 더 많이 넣으라니까는".
//
// [근본 원인] `relation-meta.ts`의 GUINJI_RELATION_TYPES는 관계유형
// (예: JORYEOK) 1개당 고정 문구 1개만 가지고 있었다. 같은 유형으로
// 판정된 사람은 전부 같은 label/description을 그대로 보게 되어, 실제로는
// `judgeGuinjiRelation()`이 사람마다 다르게 계산한 chemistryScore·
// ohaengEvidence(오행 분포, 합/충 건수, 방향성, 우세 십성)가 화면에 전혀
// 반영되지 않고 버려지고 있었다.
//
// [수정 방향 — "어뷰징 없이"] 사용자가 명시적으로 "어뷰징 없이"라고
// 강조했으므로, 완전 무작위(Math.random) 텍스트를 끼워 넣지 않는다. 이
// 파일의 모든 문장은 `judgeGuinjiRelation()`이 실제로 계산한 값(방향성
// dir, 합/충 건수, 상대의 우세 십성 카테고리, 케미 점수 구간, 게스트
// 본인의 일간 오행)에서 "결정론적으로" 골라진다 — 같은 두 사람이 다시
// 계산해도 항상 같은 문장이 나오고(재현 가능), 다른 두 사람이면 계산값이
// 달라지는 한 문장도 달라진다.
//
// [글자수 확장] 기존에는 relation-meta.ts의 description 한 문장(약
// 15~25자)뿐이었다. 이 파일은 관계유형 고정 설명(앵커 1문장) +
// 방향성 문장 + 우세 기운 문장 + 합충 문장 + 케미 점수 해설 + 게스트
// 본인의 오행 성향 해설(GUINJI_CHARACTER_TYPES 재사용)까지 최대 6문단을
// 조합해, 결과 화면의 총 텍스트량을 실질적으로 늘린다.
import { GUINJI_CHARACTER_TYPES, type OhaengKey } from "@/lib/guinji-character-type";

export interface OhaengEvidenceLike {
  otherDominantCategory?: string | null;
  breakdown?: {
    dir?: string;
    hapCount?: number;
    chungCount?: number;
  };
}

const DIR_TEXT: Record<string, string> = {
  DIR_A_TO_B: "당신의 기운이 상대에게 부족한 부분을 자연스럽게 채워주는 방향이에요. 옆에 있는 것만으로 상대의 균형을 잡아주는 쪽에 가까워요.",
  DIR_B_TO_A: "상대의 기운이 당신에게 필요한 부분을 채워주는 방향이에요. 받는 게 더 많은 관계라, 곁에 있으면 마음이 한결 편해질 수 있어요.",
  DIR_TENSION: "두 분의 오행이 서로 부딪히는 지점이 있어서, 자칫하면 별것 아닌 일로 신경전이 생기기 쉬운 조합이에요. 다만 그만큼 서로를 자극해서 성장하게 만들기도 해요.",
  DIR_SIBLING: "두 분은 같은 오행을 타고나서, 비슷한 결을 가진 사이예요. 취향이나 속도가 닮아 있어서 말이 잘 통하지만, 가끔은 서로가 서로의 거울처럼 느껴질 수도 있어요.",
  DIR_HARMONY: "천간이나 지지가 서로 합(合)을 이루는 조합이라, 처음부터 별다른 노력 없이도 자연스럽게 맞아 들어가는 사이예요.",
};

const CATEGORY_TEXT: Record<string, string> = {
  인성: "당신에게는 배움과 안정감을 전해주는 인성(印星) 기운이 두드러져요. 상대에게 조언자나 든든한 버팀목처럼 느껴질 가능성이 커요.",
  식상: "당신에게는 표현력과 생산성을 자극하는 식상(食傷) 기운이 두드러져요. 상대가 당신과 있을 때 아이디어나 말이 더 잘 풀린다고 느낄 수 있어요.",
  재성: "당신에게는 실질적인 도움과 자원의 흐름을 만들어주는 재성(財星) 기운이 두드러져요. 함께 무언가를 도모할 때 특히 시너지가 나는 조합이에요.",
  비겁: "당신에게는 상대와 결이 비슷해지는 비겁(比劫) 기운이 두드러져요. 서로 닮아가면서도, 은근한 경쟁심이 함께 따라올 수 있어요.",
  관살: "당신에게는 상대를 긴장하게 만드는 관살(官殺) 기운이 두드러져요. 부담스러울 때도 있지만, 그만큼 상대를 움직이게 하는 힘이 있는 관계예요.",
};

function hapChungText(hapCount: number, chungCount: number): string {
  if (hapCount >= 2) return "합(合)이 여러 번 겹치는 조합이라, 말하지 않아도 통하는 부분이 유난히 많아요.";
  if (hapCount === 1 && chungCount === 0) return "합(合)이 뚜렷하게 하나 있어서, 서로 잘 맞는 포인트가 분명해요.";
  if (chungCount >= 2) return "충(沖)이 여러 번 겹치는 조합이라, 부딪히는 지점이 꽤 뚜렷하게 나타나요.";
  if (chungCount === 1) return "충(沖)이 하나 있어서, 가끔은 예상치 못한 데서 신경전이 생길 수 있어요.";
  return "합(合)도 충(沖)도 두드러지지 않는, 잔잔하게 흘러가는 조합이에요.";
}

function scoreBandText(score: number): string {
  if (score >= 90) return `케미 점수 ${score}점 — 이 정도로 높게 나오는 조합은 흔치 않아요. 꽤 드물게 잘 맞는 사이예요.`;
  if (score >= 80) return `케미 점수 ${score}점 — 높은 편이라, 큰 노력 없이도 편하게 오래 이어질 수 있는 조합이에요.`;
  if (score >= 70) return `케미 점수 ${score}점 — 평균보다 확실히 높은 편이라, 관계가 순조롭게 흘러가기 쉬워요.`;
  if (score >= 60) return `케미 점수 ${score}점 — 무난하게 균형 잡힌 편이에요.`;
  if (score >= 50) return `케미 점수 ${score}점 — 애매한 경계에 있어서, 서로 조금씩 맞춰가는 노력이 필요한 조합이에요.`;
  return `케미 점수 ${score}점 — 낮은 편이라, 서로 다름을 이해하고 존중하려는 노력이 특히 중요한 조합이에요.`;
}

/**
 * 게스트 본인의 일간 오행(dayMasterElement)을 이용해 `guinji-character-type.ts`
 * 의 5종 캐릭터 해설을 재사용한다. 새 사주 계산을 만들지 않고, 이미 검증된
 * 설명(오행별 성향)을 "당신 자신은 어떤 사람인지" 문단으로 그대로 붙인다 —
 * 같은 관계유형이어도 게스트의 일간 오행이 다르면 이 문단은 반드시 달라진다.
 */
function selfElementText(dayMasterElement?: string): string | null {
  if (!dayMasterElement) return null;
  const type = GUINJI_CHARACTER_TYPES[dayMasterElement as OhaengKey];
  if (!type) return null;
  return `당신 자신은 오행상 ${type.hanja}(${dayMasterElement}) 기운이 강한 '${type.title}'에 가까워요. ${type.description}`;
}

/**
 * [핵심] 관계유형(baseDescription)은 앵커 문장으로 유지하되, 실제 계산값
 * (방향성·우세십성·합충·케미점수·게스트 본인 오행)을 근거로 문단을
 * 이어붙여 사람마다 다른 결과 서술을 만든다. 반환값은 화면에 순서대로
 * 렌더링할 문단 배열이다.
 */
export function buildRelationNarrative(params: {
  baseDescription: string;
  chemistryScore: number;
  dayMasterElement?: string;
  ohaengEvidence?: OhaengEvidenceLike | null;
}): string[] {
  const { baseDescription, chemistryScore, dayMasterElement, ohaengEvidence } = params;
  const paragraphs: string[] = [baseDescription];

  const dir = ohaengEvidence?.breakdown?.dir;
  if (dir && DIR_TEXT[dir]) paragraphs.push(DIR_TEXT[dir]);

  const cat = ohaengEvidence?.otherDominantCategory;
  if (cat && CATEGORY_TEXT[cat]) paragraphs.push(CATEGORY_TEXT[cat]);

  const hapCount = ohaengEvidence?.breakdown?.hapCount;
  const chungCount = ohaengEvidence?.breakdown?.chungCount;
  if (typeof hapCount === "number" && typeof chungCount === "number") {
    paragraphs.push(hapChungText(hapCount, chungCount));
  }

  paragraphs.push(scoreBandText(chemistryScore));

  const selfText = selfElementText(dayMasterElement);
  if (selfText) paragraphs.push(selfText);

  return paragraphs;
}
