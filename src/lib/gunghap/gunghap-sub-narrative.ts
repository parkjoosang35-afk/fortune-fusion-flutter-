// 궁합지도(Gunghap Map) — 세부 카테고리(subName, 54개) 결정론적 서술 생성기.
//
// [2026-11 궁합 세부주제 체감 버그 수정 — 대표 신고 "성격/대화/감정 궁합을
// 따로 다 봤는데 다 똑같다고 나온다"] 기존 `gunghap-narrative.ts`는 파일
// 상단 주석에 명시된 대로 "분야(major) 수준 서술만 생성"하고 48(실제 54)개
// 서브카테고리는 "기존 Flutter 화면의 정적 라벨/설명을 그대로 유지"하는
// 범위였다 — 즉 '성격 궁합'·'대화 궁합'·'감정 궁합'처럼 같은 majorId(persona)
// 아래 세부 카테고리를 다르게 선택해도 결과 서술이 100% 동일하게 나오는
// 것이 기존 설계상 의도된 동작이었다. 이 파일은 그 범위를 "세부 카테고리
// 수준"으로 확장해, 100 복주머니 유료 상세 보고서가 실제로 선택한 주제에
// 따라 달라지는 내용을 담도록 한다.
//
// [절대 원칙 — 계산 엔진 자체는 변경하지 않음] 이 파일은 `gunghap-category-
// rules.ts`의 점수/등급 산정 로직을 1바이트도 건드리지 않는다. 오직 이미
// 계산된 `CategoryEvidence`(FACT)를 "어떤 세부 주제의 관점에서, 어떤 FACT를
// 우선 언급하며 풀어서 설명할지"만 다르게 할 뿐이다 — 등급(grade)·점수
// (categoryScore)는 majorId 기준으로 변하지 않는다(세부 주제를 바꿔도 "같은
// 두 사람의 같은 분야 궁합 등급"은 동일해야 정상 — 바뀌는 것은 "그 등급을
// 설명하는 글의 초점"이다).
//
// [54개 세부 카테고리 — Flutter `gunghap_data.dart`의 `ghSubs`와 1:1 대응]
// 각 세부 카테고리는 (a) Flutter 쪽에 이미 작성된 `desc`(예: "마음이 닿는
// 타이밍과 다가가는 방식")를 그대로 "초점 문구"로 재사용하고, (b) 그 주제가
// 가장 먼저 주목해야 할 FACT 신호 1~2개(primaryTags)를 지정한다. 같은
// majorId 안에서도 세부 카테고리마다 서로 다른 FACT 조합을 우선 언급하도록
// 설계해, 실제로 다른 근거·다른 문장이 나오게 한다(단순히 라벨만 바꿔
// 끼우는 것이 아님).
//
// [7단계 상세 보고서 — 2026-11 유료 보고서 분량 확대 지시] 기존 4요소
// (관계특징/잘맞는부분/갈등가능성/개선방향)에 3요소(대화와 교감의 방식/
// 관계가 깊어지는 계기/조심해야 할 순간)를 추가해 유료 상세 보고서를 7단계로
// 확장한다(지시서 원문: "유료이니 분석을 더해서... 7,8단계 만들어서 충분히
// 결과를 만들어줘야지").
import type { CategoryEvidence, GunghapCategoryId } from "./gunghap-category-rules";
import { hasConflict, hasHarmony, s1Phrase } from "./gunghap-narrative";

export const GUNGHAP_SUB_NARRATIVE_VERSION = "gunghap-sub-narrative-1.0.0";

/** 7단계 상세 보고서 공통 스키마 — Flutter `_DetailCard`가 그대로 렌더링한다. */
export interface SubNarrativeResult {
  relationshipFeature: string;
  strength: string;
  conflictRisk: string;
  communicationStyle: string;
  growthPotential: string;
  cautionPoint: string;
  improvement: string;
}

/** 서술에서 우선 언급할 FACT 신호 종류 — 세부 카테고리별로 1~2개를 골라
 * "이 주제에서는 이 근거를 먼저 본다"는 차별점을 만든다. 점수 산정에는
 * 전혀 관여하지 않는다(순수 서술 우선순위 태그). */
type EmphasisTag =
  | "s1" // 생극관계(상생/상극)
  | "s2" // 일지관계(합/충/형/파/해)
  | "yinyang" // 일간 음양조화
  | "expression" // 식상(표현력)
  | "wealth" // 재성
  | "authority" // 관성(책임·체계)
  | "selfGroup" // 비겁+인성(자존감·수용력)
  | "bond" // 사주 전체 합(hapCount)
  | "conflict" // 사주 전체 충·형
  | "branchHarmony" // 지지 육합·삼합
  | "branchConflict" // 지지 충·형
  | "elementSupply"; // 오행보완지수

interface SubProfile {
  subName: string;
  /** Flutter `gunghap_data.dart`의 해당 GHSub.desc를 그대로 재사용(UX 문구 일관성). */
  focusPhrase: string;
  primaryTags: [EmphasisTag, EmphasisTag];
}

function tagPhrase(ev: CategoryEvidence, tag: EmphasisTag): string {
  switch (tag) {
    case "s1":
      return s1Phrase(ev);
    case "s2":
      return `일지 관계가 '${ev.s2Kind}'으로 나타나는 흐름`;
    case "yinyang":
      return ev.yinYangHarmonious
        ? "음양이 서로 다르게 배합되어 자연스럽게 끌리는 구조"
        : "음양이 같은 성질로 나란히 움직이는 구조";
    case "expression": {
      const n = ev.tenGodGroupCounts["식상"] ?? 0;
      return `표현력을 담당하는 식상 기운이 ${n}회 확인되는 흐름`;
    }
    case "wealth": {
      const n = ev.tenGodGroupCounts["재성"] ?? 0;
      return `재성 기운이 ${n}회 확인되는 흐름`;
    }
    case "authority": {
      const n = ev.tenGodGroupCounts["관성"] ?? 0;
      return `관성(책임·체계) 기운이 ${n}회 확인되는 흐름`;
    }
    case "selfGroup": {
      const n = (ev.tenGodGroupCounts["비겁"] ?? 0) + (ev.tenGodGroupCounts["인성"] ?? 0);
      return `비겁·인성(자존감·수용력) 기운이 합산 ${n}회 확인되는 흐름`;
    }
    case "bond":
      return `사주 전체에 합이 ${ev.hapCount}건 확인되는 흐름`;
    case "conflict": {
      const n = ev.chungCount + ev.hyungCount;
      return `충·형 기운이 합산 ${n}건 확인되는 흐름`;
    }
    case "branchHarmony": {
      const n = ev.branchKindCounts.육합 + ev.branchKindCounts.삼합;
      return `지지 합이 ${n}건 확인되는 흐름`;
    }
    case "branchConflict": {
      const n = ev.branchKindCounts.충 + ev.branchKindCounts.형;
      return `지지 충·형이 ${n}건 확인되는 흐름`;
    }
    case "elementSupply":
      return `오행 보완 지수가 ${ev.elementSupplyScore}/5로 나타나는 흐름`;
  }
}

function buildFromProfile(ev: CategoryEvidence, profile: SubProfile): SubNarrativeResult {
  const { subName, focusPhrase, primaryTags } = profile;
  const [tagA, tagB] = primaryTags;
  const phraseA = tagPhrase(ev, tagA);
  const phraseB = tagPhrase(ev, tagB);
  const conflictCount = ev.chungCount + ev.hyungCount;

  const relationshipFeature =
    `"${subName}" 관점에서 보면, 두 사람은 ${focusPhrase}을 중심에 둔 사이이며, ` +
    `그 바탕에는 ${phraseA}이 자리합니다.`;

  const strength = hasHarmony(ev)
    ? `사주 전체에 합이 ${ev.hapCount}건 확인되는 데다, ${phraseB}까지 더해져 ` +
      `"${subName}"에서 서로를 자연스럽게 지지해 주는 힘이 있습니다.`
    : `${phraseB}이 "${subName}" 영역에서 서로를 지지해 주는 바탕이 되며, ` +
      `뚜렷한 합은 없어도 꾸준히 쌓이는 신뢰가 강점입니다.`;

  const conflictRisk = hasConflict(ev)
    ? `"${subName}"에서는 일지 관계('${ev.s2Kind}')와 충·형 기운(${conflictCount}건)이 ` +
      `변수로 작용해, 서로 예민해지는 순간이 생길 수 있습니다.`
    : `뚜렷한 충·형 요소는 확인되지 않아, "${subName}" 측면에서는 큰 갈등보다는 ` +
      `속도나 방식 차이에서 오는 작은 아쉬움 정도가 예상됩니다.`;

  const communicationStyle = ev.yinYangHarmonious
    ? `대화와 교감이라는 면에서는 ${phraseA}이 "${subName}"의 분위기를 이끌며, ` +
      `서로 다른 결이 오히려 대화를 풍부하게 만들어 줍니다.`
    : `대화와 교감이라는 면에서는 ${phraseA}이 "${subName}"의 분위기를 이끌며, ` +
      `비슷한 결을 공유하고 있어 말하지 않아도 통하는 부분이 많습니다.`;

  const growthPotential = hasHarmony(ev)
    ? `합이 ${ev.hapCount}건 확인되는 만큼, 시간이 쌓일수록 "${subName}"이(가) ` +
      `한 단계 더 깊어질 가능성이 높습니다.`
    : `지금 당장 뚜렷한 합의 기운은 없지만, ${s1Phrase(ev)}을 바탕으로 ` +
      `천천히 "${subName}"의 깊이를 더해갈 수 있습니다.`;

  const cautionPoint =
    conflictCount > 0
      ? `형·충 기운이 ${conflictCount}건 확인되는 시기에는 "${subName}"과(와) ` +
        `관련된 대화를 특히 조심스럽게 풀어가는 것이 좋습니다.`
      : `특별히 조심해야 할 충돌 신호는 확인되지 않지만, 서로의 속도` +
        `(${ev.s1Kind === "상생" ? "자연스럽게 맞춰지는 편" : "의식적으로 맞춰야 하는 편"})를 ` +
        `챙기는 것이 "${subName}"을(를) 지키는 데 도움이 됩니다.`;

  const improvement =
    `"${subName}"을(를) 더 좋게 만들고 싶다면, ${phraseA}을 있는 그대로 인정하고, ` +
    `서로의 방식 차이를 존중하는 대화를 늘려가 보세요.`;

  return {
    relationshipFeature,
    strength,
    conflictRisk,
    communicationStyle,
    growthPotential,
    cautionPoint,
    improvement,
  };
}

// ---------------- 54개 세부 카테고리 프로필 ----------------
// focusPhrase는 Flutter `gunghap_data.dart`의 `ghSubs[majorId]` desc와 동일한
// 문구를 그대로 사용한다(화면 문구와 상세 보고서 문구의 일관성 유지).

const SUB_PROFILES: Record<GunghapCategoryId, SubProfile[]> = {
  love: [
    { subName: "썸 궁합", focusPhrase: "마음이 닿는 타이밍과 다가가는 방식", primaryTags: ["s1", "expression"] },
    { subName: "연애 궁합", focusPhrase: "연인으로서 서로에게 주는 힘", primaryTags: ["bond", "expression"] },
    { subName: "짝사랑 궁합", focusPhrase: "한쪽의 마음이 닿을 수 있는 길", primaryTags: ["s1", "yinyang"] },
    { subName: "재회 궁합", focusPhrase: "다시 이어질 인연의 흐름", primaryTags: ["bond", "conflict"] },
    { subName: "장거리 연애 궁합", focusPhrase: "거리를 넘어서는 두 사람의 방식", primaryTags: ["elementSupply", "authority"] },
    { subName: "애정표현 궁합", focusPhrase: "사랑을 말하고 받아들이는 언어", primaryTags: ["expression", "yinyang"] },
    { subName: "이상형 궁합", focusPhrase: "서로가 그리던 모습과의 거리", primaryTags: ["elementSupply", "s1"] },
  ],
  marriage: [
    { subName: "결혼 궁합", focusPhrase: "평생을 함께할 인연의 결", primaryTags: ["s2", "elementSupply"] },
    { subName: "부부 궁합", focusPhrase: "한 집에서 맞춰가는 두 사람", primaryTags: ["elementSupply", "authority"] },
    { subName: "신혼 궁합", focusPhrase: "함께 시작하는 첫 몇 해의 흐름", primaryTags: ["bond", "s1"] },
    { subName: "배우자 궁합", focusPhrase: "서로에게 어떤 배우자가 되는지", primaryTags: ["wealth", "authority"] },
    { subName: "결혼 시기 궁합", focusPhrase: "두 사람의 운이 모이는 때", primaryTags: ["s2", "bond"] },
    { subName: "생활 궁합", focusPhrase: "일상의 습관과 리듬의 조화", primaryTags: ["elementSupply", "s1"] },
    { subName: "노후 궁합", focusPhrase: "오래 함께 걸어갈 길", primaryTags: ["authority", "branchHarmony"] },
  ],
  intimacy: [
    { subName: "스킨십 궁합", focusPhrase: "몸으로 전하는 마음의 속도", primaryTags: ["yinyang", "s2"] },
    { subName: "감정 친밀감 궁합", focusPhrase: "속마음을 나누는 깊이", primaryTags: ["bond", "yinyang"] },
    { subName: "애정 온도 궁합", focusPhrase: "두 사람이 편안한 온도 차이", primaryTags: ["yinyang", "s1"] },
    { subName: "로맨틱 궁합", focusPhrase: "특별한 순간을 만드는 방식", primaryTags: ["expression", "bond"] },
    { subName: "밀착형·독립형 궁합", focusPhrase: "함께와 혼자 사이의 균형", primaryTags: ["yinyang", "selfGroup"] },
    { subName: "친밀감 소통 궁합", focusPhrase: "가까움을 말로 나누는 법", primaryTags: ["expression", "yinyang"] },
  ],
  persona: [
    { subName: "성격 궁합", focusPhrase: "타고난 기질이 만나는 모습", primaryTags: ["s1", "selfGroup"] },
    { subName: "대화 궁합", focusPhrase: "말이 통하는 결과 속도", primaryTags: ["expression", "s1"] },
    { subName: "감정 궁합", focusPhrase: "감정을 느끼고 표현하는 방식", primaryTags: ["expression", "yinyang"] },
    { subName: "가치관 궁합", focusPhrase: "중요하게 여기는 것의 차이", primaryTags: ["selfGroup", "s1"] },
    { subName: "갈등 궁합", focusPhrase: "부딪힐 때와 풀어갈 때", primaryTags: ["conflict", "s1"] },
    { subName: "공감 궁합", focusPhrase: "서로의 마음을 알아채는 힘", primaryTags: ["selfGroup", "yinyang"] },
    { subName: "리더십 궁합", focusPhrase: "누가, 언제 앞장서는지", primaryTags: ["authority", "s1"] },
  ],
  wealth: [
    { subName: "돈 관리 궁합", focusPhrase: "함께 돈을 다루는 방식", primaryTags: ["wealth", "elementSupply"] },
    { subName: "소비 궁합", focusPhrase: "쓰는 기준과 즐거움의 차이", primaryTags: ["expression", "wealth"] },
    { subName: "저축 궁합", focusPhrase: "모으는 속도와 인내의 결", primaryTags: ["elementSupply", "authority"] },
    { subName: "재산 형성 궁합", focusPhrase: "함께 키워가는 재물의 흐름", primaryTags: ["wealth", "bond"] },
    { subName: "경제관념 궁합", focusPhrase: "돈에 대한 기본 생각", primaryTags: ["wealth", "s1"] },
    { subName: "투자 성향 궁합", focusPhrase: "위험과 기회를 보는 눈", primaryTags: ["wealth", "conflict"] },
  ],
  business: [
    { subName: "동업 궁합", focusPhrase: "함께 일을 꾸릴 때의 합", primaryTags: ["bond", "authority"] },
    { subName: "창업 궁합", focusPhrase: "시작하는 힘과 버티는 힘", primaryTags: ["expression", "authority"] },
    { subName: "CEO·파트너 궁합", focusPhrase: "이끄는 사람과 받쳐주는 사람", primaryTags: ["authority", "selfGroup"] },
    { subName: "업무 궁합", focusPhrase: "일하는 방식과 속도의 조화", primaryTags: ["expression", "s1"] },
    { subName: "의사결정 궁합", focusPhrase: "결정을 내리는 두 사람의 방식", primaryTags: ["authority", "conflict"] },
    { subName: "금전 사업 궁합", focusPhrase: "사업 속 돈의 흐름", primaryTags: ["wealth", "bond"] },
    { subName: "조직관리 궁합", focusPhrase: "사람을 이끄는 두 가지 방식", primaryTags: ["selfGroup", "elementSupply"] },
  ],
  friend: [
    { subName: "절친 궁합", focusPhrase: "오래 곁에 남을 우정의 결", primaryTags: ["selfGroup", "bond"] },
    { subName: "친구 궁합", focusPhrase: "편안하게 어울리는 방식", primaryTags: ["selfGroup", "s1"] },
    { subName: "여행 궁합", focusPhrase: "함께 떠났을 때의 리듬", primaryTags: ["yinyang", "bond"] },
    { subName: "직장 동료 궁합", focusPhrase: "일터에서 서로에게 주는 힘", primaryTags: ["authority", "selfGroup"] },
    { subName: "취미 궁합", focusPhrase: "함께 즐길 수 있는 것들", primaryTags: ["bond", "expression"] },
    { subName: "라이벌 궁합", focusPhrase: "서로를 자라게 하는 경쟁", primaryTags: ["conflict", "selfGroup"] },
    { subName: "인간관계 궁합", focusPhrase: "사람을 대하는 두 사람의 방식", primaryTags: ["selfGroup", "yinyang"] },
  ],
  family: [
    { subName: "부모·자녀 궁합", focusPhrase: "서로를 이해하는 세대의 거리", primaryTags: ["authority", "branchHarmony"] },
    { subName: "아버지·자녀 궁합", focusPhrase: "말보다 깊은 마음의 결", primaryTags: ["authority", "s1"] },
    { subName: "어머니·자녀 궁합", focusPhrase: "가장 가까운 마음의 흐름", primaryTags: ["selfGroup", "branchHarmony"] },
    { subName: "형제·자매 궁합", focusPhrase: "함께 자란 두 별의 관계", primaryTags: ["selfGroup", "branchConflict"] },
    { subName: "시부모·며느리 궁합", focusPhrase: "새로운 가족이 맞춰가는 법", primaryTags: ["branchConflict", "authority"] },
    { subName: "장인·장모·사위 궁합", focusPhrase: "존중으로 이어지는 인연", primaryTags: ["authority", "elementSupply"] },
    { subName: "가족 생활 궁합", focusPhrase: "한 지붕 아래의 리듬", primaryTags: ["elementSupply", "branchHarmony"] },
  ],
};

function findProfile(majorId: GunghapCategoryId, subName: string): SubProfile | null {
  const list = SUB_PROFILES[majorId];
  if (!list) return null;
  return list.find((p) => p.subName === subName) ?? null;
}

/** 54개 등록된 세부 카테고리 중 하나와 정확히 일치하면 그 전용 서술을
 * 생성한다. 일치하지 않으면(오타, 신규 추가 전 과도기 등) null을 반환한다 —
 * 호출부가 `buildFreeNarrative7()`을 통해 안전하게 일반 버전으로 degrade한다. */
export function generateSubNarrative(
  majorId: GunghapCategoryId,
  subName: string,
  ev: CategoryEvidence,
): SubNarrativeResult | null {
  const profile = findProfile(majorId, subName);
  if (!profile) return null;
  return buildFromProfile(ev, profile);
}

/** [하위 호환 — subName이 없거나 등록되지 않은 경우] 분야(major) 수준
 * 4요소 서술(`gunghap-narrative.ts`가 이미 생성해 둔 것)의 앞 3개 필드는
 * 그대로 재사용하고, 나머지 4개는 분야 라벨 기준 범용 문장으로 채워
 * 7단계 스키마를 항상 동일하게 유지한다(Flutter 렌더링 단순화 목적). */
export function generateMajorFallbackNarrative(
  majorId: GunghapCategoryId,
  ev: CategoryEvidence,
  majorFourField: { relationshipFeature: string; strength: string; conflictRisk: string; improvement: string },
): SubNarrativeResult {
  const conflictCount = ev.chungCount + ev.hyungCount;
  return {
    relationshipFeature: majorFourField.relationshipFeature,
    strength: majorFourField.strength,
    conflictRisk: majorFourField.conflictRisk,
    communicationStyle: ev.yinYangHarmonious
      ? "대화와 교감이라는 면에서는 서로 다른 결이 오히려 대화를 풍부하게 만들어 줍니다."
      : "대화와 교감이라는 면에서는 비슷한 결을 공유하고 있어 말하지 않아도 통하는 부분이 많습니다.",
    growthPotential: hasHarmony(ev)
      ? `합이 ${ev.hapCount}건 확인되는 만큼, 시간이 쌓일수록 관계가 한 단계 더 깊어질 가능성이 높습니다.`
      : `지금 당장 뚜렷한 합의 기운은 없지만, ${s1Phrase(ev)}을 바탕으로 천천히 관계의 깊이를 더해갈 수 있습니다.`,
    cautionPoint:
      conflictCount > 0
        ? `형·충 기운이 ${conflictCount}건 확인되는 시기에는 대화를 조심스럽게 풀어가는 것이 좋습니다.`
        : "특별히 조심해야 할 충돌 신호는 확인되지 않지만, 서로의 속도를 챙기는 것이 좋습니다.",
    improvement: majorFourField.improvement,
  };
}

/** [통합 진입점] unlock/route.ts가 호출하는 단일 함수 — subName이 54개
 * 등록 목록에 있으면 전용 서술을, 없으면 안전하게 범용 7단계로 degrade한다. */
export function buildFreeNarrative7(
  majorId: GunghapCategoryId,
  subName: string | null | undefined,
  ev: CategoryEvidence,
  majorFourField: { relationshipFeature: string; strength: string; conflictRisk: string; improvement: string },
): SubNarrativeResult {
  if (subName) {
    const specific = generateSubNarrative(majorId, subName, ev);
    if (specific) return specific;
  }
  return generateMajorFallbackNarrative(majorId, ev, majorFourField);
}
