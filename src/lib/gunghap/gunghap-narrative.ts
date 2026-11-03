// 궁합지도(Gunghap Map) — FACT 기반 서술 생성기.
//
// [신통방통 궁합지도 개발 지시서 §3 대응] 8개 분야 각각에 대해 4개 서술
// 요소(관계 특징 / 잘 맞는 부분 / 갈등 가능성 / 관계 개선 방향)를 생성
// 한다.
//
// [절대 원칙 — 개발 승인 §2-5, §2-6 그대로 인용]
// "근거가 없는 궁합 해석, 임의 점수, 가짜 통계는 생성하지 않는다."
// "각 분야의 관계 특징·잘 맞는 부분·갈등 가능성·개선 방향은 계산 FACT와
// 연결되어야 한다."
//
// [구현 방식 — 템플릿은 "문장 틀"일 뿐, 선택은 FACT가 한다] 이 파일은
// 자연어를 자유 생성(LLM 등)하지 않는다. 각 문장은 `CategoryGradeResult.
// evidence`(= `gunghap-category-rules.ts`가 분야 판정에 실제로 사용한
// FACT)의 조건 분기에 따라 **결정론적으로** 선택된 고정 문장 조각들을
// 조립한 것이다 — 즉 "이 문장이 나온 이유"는 항상 특정 FACT 필드 값으로
// 역추적 가능하다(`factRefs`에 그 근거 필드명을 명시해 반환한다).
//
// [결정론] 동일한 CategoryGradeResult 입력 → 항상 동일한 4문장 출력.
//
// [미노출 서브카테고리 범위] 분야(major) 수준 서술만 생성한다 — 48개
// 서브카테고리(`gunghap_data.dart`의 `ghSubs`) 각각에 대한 별도 서술
// 로직은 지시서 §3이 요구하는 범위가 아니다(8개 분야당 4요소 — major
// 수준). 서브카테고리는 기존 Flutter 화면의 정적 라벨/설명을 그대로
// 유지한다(개발 원칙 "기존 서비스 기능을 임의로 변경하지 않는다").

import type { CategoryEvidence, CategoryGradeResult, GunghapCategoryId } from "./gunghap-category-rules";

export const GUNGHAP_NARRATIVE_VERSION = "gunghap-narrative-1.0.0";

export interface CategoryNarrative {
  categoryId: GunghapCategoryId;
  grade: string;
  /** 두 사람의 관계 특징. */
  relationshipFeature: string;
  /** 잘 맞는 부분. */
  strength: string;
  /** 갈등 가능성. */
  conflictRisk: string;
  /** 관계 개선 방향. */
  improvement: string;
  /** 위 4문장이 각각 근거로 삼은 FACT 필드명(투명성/검수용, 화면 비노출). */
  factRefs: {
    relationshipFeature: string[];
    strength: string[];
    conflictRisk: string[];
    improvement: string[];
  };
}

const CATEGORY_LABEL: Record<GunghapCategoryId, string> = {
  love: "연애",
  marriage: "결혼",
  intimacy: "속궁합",
  persona: "성격",
  wealth: "재물",
  business: "사업",
  friend: "친구",
  family: "가족",
};

function hasConflict(ev: CategoryEvidence): boolean {
  return ev.chungCount > 0 || ev.hyungCount > 0 || ev.branchKindCounts.충 > 0 || ev.branchKindCounts.형 > 0;
}

function hasHarmony(ev: CategoryEvidence): boolean {
  return ev.hapCount > 0 || ev.branchKindCounts.육합 > 0 || ev.branchKindCounts.삼합 > 0;
}

// ---------------- S1 서술 보조(공통) ----------------

function s1Phrase(ev: CategoryEvidence): string {
  if (ev.s1Kind === "상생") {
    return ev.s1Direction === "out"
      ? "한쪽의 기운이 다른 쪽을 북돋아 주는 상생의 흐름"
      : "상대의 기운이 자연스럽게 나를 북돋아 주는 상생의 흐름";
  }
  if (ev.s1Kind === "상극") return "서로 기운이 부딪히며 긴장과 자극이 함께 따르는 상극의 흐름";
  if (ev.s1Kind === "비화") return "같은 기운으로 결이 비슷해 편안하게 맞춰지는 흐름";
  return "뚜렷한 생극 관계는 없이 각자의 기운을 유지하는 흐름";
}

// ---------------- 분야별 서술 생성기 ----------------

function narrateLove(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const expr = ev.tenGodGroupCounts["식상"] ?? 0;
  const feature = `두 사람은 ${s1Phrase(ev)}을 바탕에 둔 인연이며, 음양 기운은 ${
    ev.yinYangHarmonious ? "서로 다르게 맞물려" : "같은 성질로 나란히 움직여"
  } 끌림의 결이 형성됩니다.`;
  const strength = hasHarmony(ev)
    ? `사주에 합이 ${ev.hapCount}건 확인되어, 자연스럽게 서로에게 다가가고 마음을 여는 힘이 있습니다.`
    : expr > 0
    ? `식상(표현·감정) 기운이 ${expr}회 나타나 애정 표현에 있어 서로를 편안하게 만들어 줍니다.`
    : `오행 보완 지수가 ${ev.elementSupplyScore}/5로 확인되어, 서로 부족한 기운을 채워주는 관계입니다.`;
  const conflictRisk = hasConflict(ev)
    ? `일지 관계가 '${ev.s2Kind}'으로 나타나 감정이 급해지거나 오해가 쌓이는 순간이 생길 수 있습니다.`
    : `뚜렷한 충·형 요소는 확인되지 않아, 큰 갈등보다는 서로 속도 차이에서 오는 작은 아쉬움 정도가 예상됩니다.`;
  const improvement = `표현의 속도와 방식 차이를 인정하고, 서로의 기운(${ev.s1Kind})이 지닌 성향을 있는 그대로 받아들이는 대화를 늘려가면 관계가 더 단단해집니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["s1Kind", "s1Direction", "yinYangHarmonious"],
      strength: ["hapCount", "tenGodGroupCounts.식상", "elementSupplyScore"],
      conflictRisk: ["chungCount", "hyungCount", "s2Kind"],
      improvement: ["s1Kind"],
    },
  };
}

function narrateMarriage(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const stability = (ev.tenGodGroupCounts["재성"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0);
  const feature = `두 사람의 일지 관계는 '${ev.s2Kind}'으로, 이는 부부가 함께 살아가는 일상의 기본 결을 보여줍니다. 오행 보완 지수는 ${ev.elementSupplyScore}/5입니다.`;
  const strength = stability > 0
    ? `재성·관성 기운이 합산 ${stability}회 확인되어, 생활의 안정과 책임감을 함께 만들어가는 바탕이 있습니다.`
    : `${s1Phrase(ev)}이 부부 생활의 기본 리듬을 만들어 줍니다.`;
  const conflictRisk = ev.s2Kind === "충" || ev.s2Kind === "형"
    ? `일지가 '${ev.s2Kind}' 관계라 생활 방식이나 습관 차이로 부딪히는 지점이 분명히 있을 수 있습니다.`
    : ev.chungCount + ev.hyungCount > 0
    ? `사주 전체에서 충·형이 ${ev.chungCount + ev.hyungCount}건 확인되어, 특정 시기나 사안에서 의견 차이가 커질 수 있습니다.`
    : `일지 관계에 뚜렷한 충돌 요소가 없어, 생활 전반에서 큰 마찰보다는 조율의 과정이 중심이 됩니다.`;
  const improvement = `생활 보완 지수(${ev.elementSupplyScore}/5)를 참고해, 서로 부족한 부분을 채워주는 역할 분담을 의식적으로 정해두면 장기적인 안정에 도움이 됩니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["s2Kind", "elementSupplyScore"],
      strength: ["tenGodGroupCounts.재성", "tenGodGroupCounts.관성", "s1Kind"],
      conflictRisk: ["s2Kind", "chungCount", "hyungCount"],
      improvement: ["elementSupplyScore"],
    },
  };
}

function narrateIntimacy(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const feature = `일간의 음양이 ${ev.yinYangHarmonious ? "서로 달라 조화를 이루는" : "같은 성질로 나란한"} 구조이며, 일지(배우자궁) 관계는 '${ev.s2Kind}'입니다.`;
  const strength = ev.yinYangHarmonious
    ? `음양이 서로 다르게 배합되어 있어, 가까워질수록 자연스럽게 서로를 끌어당기는 힘이 있습니다.`
    : hasHarmony(ev)
    ? `일지 합이 ${ev.hapCount}건 확인되어, 가까운 사이일수록 편안함이 깊어지는 흐름입니다.`
    : `같은 기운을 공유하고 있어 서로의 리듬을 이해하기 쉬운 면이 있습니다.`;
  const conflictRisk = !ev.yinYangHarmonious && !hasHarmony(ev)
    ? `음양 배합이 같은 성질이고 일지에 특별한 합도 없어, 친밀감의 온도 차이를 스스로 느낄 수 있습니다.`
    : hasConflict(ev)
    ? `일지 관계에 충·형 요소가 포함되어 있어, 가까워지는 속도에 대한 눈높이 차이가 생길 수 있습니다.`
    : `뚜렷한 긴장 요소는 확인되지 않습니다.`;
  const improvement = `서로 편안함을 느끼는 속도(${ev.yinYangHarmonious ? "자연스럽게 끌리는 편" : "천천히 가까워지는 편"})가 다를 수 있다는 점을 전제로, 충분한 대화를 통해 서로의 리듬에 맞춰가는 것이 좋습니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["yinYangHarmonious", "s2Kind"],
      strength: ["yinYangHarmonious", "hapCount"],
      conflictRisk: ["yinYangHarmonious", "hapCount", "chungCount", "hyungCount"],
      improvement: ["yinYangHarmonious"],
    },
  };
}

function narratePersona(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const selfGroups = (ev.tenGodGroupCounts["비겁"] ?? 0) + (ev.tenGodGroupCounts["인성"] ?? 0);
  const feature = `두 사람의 기질은 ${s1Phrase(ev)}으로 요약됩니다.`;
  const strength = selfGroups > 0
    ? `비겁·인성 기운이 합산 ${selfGroups}회 나타나, 서로의 자존감과 수용적인 태도를 이해해 주는 면이 있습니다.`
    : `${ev.s1Kind === "상생" ? "서로의 부족한 면을 자연스럽게 채워주는" : "각자의 개성을 뚜렷하게 유지하는"} 관계입니다.`;
  const conflictCount = ev.hyungCount + ev.chungCount;
  const conflictRisk = conflictCount > 0
    ? `형·충 기운이 합산 ${conflictCount}건 확인되어, 기질적으로 부딪히는 순간이 분명히 존재할 수 있습니다.`
    : `형·충 기운이 발견되지 않아, 기질 차이로 인한 큰 마찰보다는 서로 다른 속도를 맞춰가는 과정이 중심이 됩니다.`;
  const improvement = ev.s1Kind === "상극"
    ? `서로 기운이 부딪히는 상극 관계인 만큼, 의견 차이를 감정적 대립이 아니라 관점의 차이로 받아들이는 연습이 필요합니다.`
    : `서로의 기질(${ev.s1Kind})을 인정하고, 강점을 살리는 방향으로 역할을 나누면 관계가 한층 편안해집니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["s1Kind"],
      strength: ["tenGodGroupCounts.비겁", "tenGodGroupCounts.인성", "s1Kind"],
      conflictRisk: ["hyungCount", "chungCount"],
      improvement: ["s1Kind"],
    },
  };
}

function narrateWealth(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const wealthGroup = ev.tenGodGroupCounts["재성"] ?? 0;
  const feature = `두 사람의 사주 전체에서 재성(財星) 기운이 ${wealthGroup}회 확인되며, 오행 보완 지수는 ${ev.elementSupplyScore}/5입니다.`;
  const strength = wealthGroup > 0
    ? `재성 기운이 뚜렷하게 나타나 있어, 함께 재물을 계획하고 늘려가는 데 있어 긍정적인 바탕이 있습니다.`
    : ev.elementSupplyScore >= 3
    ? `오행 보완 지수가 높아, 서로의 소비·저축 성향이 균형을 맞춰주는 관계입니다.`
    : `${s1Phrase(ev)}이 재물에 대한 기본 태도에도 영향을 줍니다.`;
  const conflictRisk = wealthGroup === 0 && ev.elementSupplyScore < 2
    ? `재성 기운과 오행 보완이 모두 낮게 나타나, 돈에 대한 가치관 차이로 의견이 갈릴 수 있습니다.`
    : `재물 관련 기운 자체에 뚜렷한 긴장 요소는 확인되지 않지만, 씀씀이의 '방식' 차이는 대화로 맞춰갈 필요가 있습니다.`;
  const improvement = `재성 기운(${wealthGroup}회)과 오행 보완 지수(${ev.elementSupplyScore}/5)를 참고해, 공동 자금 운용 규칙을 미리 정해두면 재물 궁합을 더 안정적으로 만들 수 있습니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["tenGodGroupCounts.재성", "elementSupplyScore"],
      strength: ["tenGodGroupCounts.재성", "elementSupplyScore", "s1Kind"],
      conflictRisk: ["tenGodGroupCounts.재성", "elementSupplyScore"],
      improvement: ["tenGodGroupCounts.재성", "elementSupplyScore"],
    },
  };
}

function narrateBusiness(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const drive = (ev.tenGodGroupCounts["식상"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0);
  const feature = `추진력과 체계(식상·관성) 기운이 합산 ${drive}회 확인되며, 사주 전체의 합은 ${ev.hapCount}건, 충·형은 ${
    ev.chungCount + ev.hyungCount
  }건입니다.`;
  const strength = ev.hapCount > 0
    ? `합이 ${ev.hapCount}건 확인되어, 함께 일을 도모할 때 손발이 잘 맞는 협업의 기운이 있습니다.`
    : drive > 0
    ? `추진력과 체계를 담당하는 기운이 뚜렷해, 역할을 나누어 일을 진행하기에 좋은 조합입니다.`
    : `${s1Phrase(ev)}이 업무 스타일에도 비슷하게 반영됩니다.`;
  const conflictRisk = ev.chungCount + ev.hyungCount > 0
    ? `충·형 기운이 합산 ${ev.chungCount + ev.hyungCount}건 확인되어, 의사결정 과정에서 주도권이나 방향성을 둘러싼 갈등이 생길 수 있습니다.`
    : `충·형 요소가 확인되지 않아, 큰 갈등보다는 추진 속도 차이를 조율하는 정도가 예상됩니다.`;
  const improvement = `역할과 책임 범위를 사전에 명확히 나누고, 합(${ev.hapCount}건)이 주는 협업의 힘을 살리는 방향으로 업무를 설계하면 동업·협력의 안정성이 높아집니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["tenGodGroupCounts.식상", "tenGodGroupCounts.관성", "hapCount", "chungCount", "hyungCount"],
      strength: ["hapCount", "tenGodGroupCounts.식상", "tenGodGroupCounts.관성"],
      conflictRisk: ["chungCount", "hyungCount"],
      improvement: ["hapCount"],
    },
  };
}

function narrateFriend(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const peer = ev.tenGodGroupCounts["비겁"] ?? 0;
  const feature = `비겁(동류의식) 기운이 ${peer}회 확인되며, 합은 ${ev.hapCount}건입니다.`;
  const strength = peer > 0
    ? `비겁 기운이 뚜렷해, 또래처럼 편안하게 어울리고 서로를 동등하게 대하는 관계입니다.`
    : ev.hapCount > 0
    ? `합이 ${ev.hapCount}건 확인되어, 오래갈수록 의리와 신뢰가 쌓이는 흐름입니다.`
    : `${s1Phrase(ev)}이 두 사람이 어울리는 방식의 바탕이 됩니다.`;
  const conflictRisk = ev.chungCount + ev.hyungCount > 0
    ? `충·형 기운이 일부 확인되지만, 친구 사이에서는 서로 다른 점이 오히려 자극이 되는 경우도 많습니다.`
    : `충·형 요소가 거의 없어, 편하게 오래 어울릴 수 있는 궁합입니다.`;
  const improvement = `서로의 거리감(가까움과 적당한 독립성)을 존중하면서, 비겁 기운(${peer}회)이 주는 동질감을 살려 자주 교류하는 것이 관계를 오래 유지하는 데 도움이 됩니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["tenGodGroupCounts.비겁", "hapCount"],
      strength: ["tenGodGroupCounts.비겁", "hapCount", "s1Kind"],
      conflictRisk: ["chungCount", "hyungCount"],
      improvement: ["tenGodGroupCounts.비겁"],
    },
  };
}

function narrateFamily(ev: CategoryEvidence): Omit<CategoryNarrative, "categoryId" | "grade"> {
  const care = (ev.tenGodGroupCounts["인성"] ?? 0) + (ev.tenGodGroupCounts["관성"] ?? 0);
  const harmonyBranches = ev.branchKindCounts.육합 + ev.branchKindCounts.삼합;
  const conflictBranches = ev.branchKindCounts.충 + ev.branchKindCounts.형;
  const feature = `돌봄·위계(인성·관성) 기운이 합산 ${care}회, 지지 조합 중 합이 ${harmonyBranches}건, 충·형이 ${conflictBranches}건 확인됩니다.`;
  const strength = harmonyBranches > 0
    ? `지지 합이 ${harmonyBranches}건 확인되어, 가족 구성원 간 자연스러운 유대와 안정감이 있는 관계입니다.`
    : care > 0
    ? `인성·관성 기운이 뚜렷해, 서로를 보살피고 위아래 예를 지키는 결이 있습니다.`
    : `${s1Phrase(ev)}이 가족 사이의 기본적인 관계 결을 보여줍니다.`;
  const conflictRisk = conflictBranches > 0
    ? `지지 조합에서 충·형이 ${conflictBranches}건 확인되어, 가족 간 입장 차이나 세대 차이로 인한 마찰 가능성이 다른 분야보다 더 주의가 필요합니다.`
    : `지지 조합에 뚜렷한 충돌 요소가 없어, 가족으로서 비교적 안정적인 관계가 예상됩니다.`;
  const improvement = conflictBranches > 0
    ? `충·형이 확인된 만큼, 중요한 결정을 할 때는 서로의 입장을 먼저 충분히 듣는 자리를 마련하는 것이 갈등을 줄이는 데 도움이 됩니다.`
    : `지금의 안정적인 흐름을 유지하기 위해, 정기적으로 서로의 안부와 상황을 나누는 시간을 꾸준히 이어가는 것이 좋습니다.`;
  return {
    relationshipFeature: feature,
    strength,
    conflictRisk,
    improvement,
    factRefs: {
      relationshipFeature: ["tenGodGroupCounts.인성", "tenGodGroupCounts.관성", "branchKindCounts.육합", "branchKindCounts.삼합", "branchKindCounts.충", "branchKindCounts.형"],
      strength: ["branchKindCounts.육합", "branchKindCounts.삼합", "tenGodGroupCounts.인성", "tenGodGroupCounts.관성"],
      conflictRisk: ["branchKindCounts.충", "branchKindCounts.형"],
      improvement: ["branchKindCounts.충", "branchKindCounts.형"],
    },
  };
}

const NARRATORS: Record<GunghapCategoryId, (ev: CategoryEvidence) => Omit<CategoryNarrative, "categoryId" | "grade">> = {
  love: narrateLove,
  marriage: narrateMarriage,
  intimacy: narrateIntimacy,
  persona: narratePersona,
  wealth: narrateWealth,
  business: narrateBusiness,
  friend: narrateFriend,
  family: narrateFamily,
};

/** 단일 분야 결과(`gradeCategory()` 반환값)로부터 4요소 서술을 생성한다. */
export function narrateCategory(result: CategoryGradeResult): CategoryNarrative {
  const body = NARRATORS[result.categoryId](result.evidence);
  return {
    categoryId: result.categoryId,
    grade: result.grade,
    ...body,
  };
}

/** 8개 분야 전체 서술 생성(고정 순서는 입력 배열 순서를 따른다). */
export function narrateAllCategories(results: CategoryGradeResult[]): CategoryNarrative[] {
  return results.map((r) => narrateCategory(r));
}

/** 분야 한글 라벨 — gunghap_data.dart의 ghMajors.name과 동일(참고용 export). */
export function categoryLabel(id: GunghapCategoryId): string {
  return CATEGORY_LABEL[id];
}
