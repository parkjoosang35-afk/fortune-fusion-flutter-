// [정통사주 리뉴얼 v1.0] 주제 카탈로그 v1 확정 데이터 — 최종지시서 7장 원문 그대로.
//
// 출처: saju-final-directive.pdf §7 "주제 카탈로그 v1 확정(29종 — 릴리즈1 활성26 +
// 폴백1 + 2차2)". topicId/topicName/requiredFacts/releasePhase/isTiming은 전부
// 지시서 원문을 그대로 옮긴 것이며, 이 파일에서 새로 만들거나 추정한 값은 없다.
//
// [sortOrder 규칙] 디자인팀 승인조건① "동점 처리 규칙 명시"에 따라, topic-engine.ts의
// 정렬 1순위로 쓰인다. 이 배열의 선언 순서(=지시서 표 순서, LIFE_000 폴백 → MONEY →
// TALENT → PERSONALITY → RELATION → LOVE → LIFE)를 그대로 sortOrder로 매핑한다.
//
// [시기형(isTiming) 목록 — 지시서 §7 각주] MONEY_004, TALENT_004, TALENT_005,
// LOVE_005, LOVE_006, LIFE_001~004, LIFE_006. 세션당 최대 1개만 후보에 포함된다
// (topic-engine.ts 필터 단계에서 강제).
//
// [필수 Fact(requiredFacts)] 지시서가 "필수 Fact(실측 키)" 열에 명시한 한국어
// 키워드를 그대로 보관한다 — 이 값은 TopicCondition 테이블의 conditionValue
// 시딩에 사용되며, topic-engine.ts는 아직 이 키들을 saju_v3 facts 응답의 실제
// 필드명으로 매핑하는 단계(§필터 "충족 근거 ≥2")만 구현하고, 세부 판정 규칙은
// 운영 중 조정 가능하도록 TopicCondition 레코드로 분리해 코드에 하드코딩하지
// 않는다(지시서 "개발자 임의 결정 금지" 원칙을 DB 레벨에서도 지킨다).

export interface TopicCatalogSeedItem {
  topicId: string;
  topicName: string;
  categoryGroup:
    | "LIFE"
    | "MONEY"
    | "TALENT"
    | "PERSONALITY"
    | "RELATION"
    | "LOVE";
  isTiming: boolean;
  isFallback: boolean;
  releasePhase: 1 | 2;
  /** 지시서 §7 "필수 Fact(실측 키)" 열 원문(한국어 키워드 나열, 콤마 등 구분자는 지시서 표기 그대로). */
  requiredFacts: string;
  /** 특이 조건·중복 페어 등 지시서 비고. 없으면 null. */
  note: string | null;
}

export const TOPIC_CATALOG_SEED: TopicCatalogSeedItem[] = [
  // ── 폴백(항상 활성) ──
  {
    topicId: "LIFE_000",
    topicName: "평생 총론",
    categoryGroup: "LIFE",
    isTiming: false,
    isFallback: true,
    releasePhase: 1,
    requiredFacts: "pillars · five_elements · yongshin · strength · luck_pillars",
    note: "폴백 — A01 근거. 후보 0건 구조적 불가를 보장하는 상시 후보.",
  },
  // ── MONEY (재물) ──
  {
    topicId: "MONEY_001",
    topicName: "당신에게 돈이 들어오는 방식",
    categoryGroup: "MONEY",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "재성 유형·강약 · 오행 · 용신-재성 관계",
    note: null,
  },
  {
    topicId: "MONEY_002",
    topicName: "돈을 버는 사람인가, 모으는 사람인가",
    categoryGroup: "MONEY",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "편재/정재 비중 · 겁재 · 식상",
    note: null,
  },
  {
    topicId: "MONEY_003",
    topicName: "돈을 벌어도 남기기 어려운 이유",
    categoryGroup: "MONEY",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "비겁 과다 · 재성 인접 충·해 (특이 조건)",
    note: "RELATION_003과 중복 페어",
  },
  {
    topicId: "MONEY_004",
    topicName: "재물 기회가 커지는 시기",
    categoryGroup: "MONEY",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "luck_pillars 재성 유입 · 용신 관계 · 세운",
    note: "시기형",
  },
  {
    topicId: "MONEY_005",
    topicName: "사업과 직장의 재물 흐름 차이",
    categoryGroup: "MONEY",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "편재 vs 정관 비중 · 격국",
    note: null,
  },
  {
    topicId: "MONEY_006",
    topicName: "당신의 투자 성향",
    categoryGroup: "MONEY",
    isTiming: false,
    isFallback: false,
    releasePhase: 2,
    requiredFacts: "편재/정재 · 겁재 · 오행",
    note: null,
  },
  // ── TALENT (재능·직업) ──
  {
    topicId: "TALENT_001",
    topicName: "남들보다 쉽게 해내는 일",
    categoryGroup: "TALENT",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "십신 편중(≥35%) · 격국 · 강약",
    note: null,
  },
  {
    topicId: "TALENT_002",
    topicName: "혼자 강한가, 함께할 때 강한가",
    categoryGroup: "TALENT",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "비겁 vs 관성+식상 비율",
    note: null,
  },
  {
    topicId: "TALENT_003",
    topicName: "조직에서 강점을 발휘하는 순간",
    categoryGroup: "TALENT",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "관성 상태 · 강약",
    note: null,
  },
  {
    topicId: "TALENT_004",
    topicName: "뒤늦게 발견하게 되는 재능",
    categoryGroup: "TALENT",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "용신 오행이 후반 대운 등장 (특이 조건)",
    note: "시기형",
  },
  {
    topicId: "TALENT_005",
    topicName: "직업 방향이 바뀌는 흐름",
    categoryGroup: "TALENT",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "대운 관성 전환 · 일지 충",
    note: "시기형",
  },
  // ── PERSONALITY (기질) ──
  {
    topicId: "PERSONALITY_001",
    topicName: "당신이 태어날 때부터 가지고 태어난 것",
    categoryGroup: "PERSONALITY",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "십신 5그룹 분포 · 일간 · 오행 (A02 근거)",
    note: null,
  },
  // ── RELATION (관계) ──
  {
    topicId: "RELATION_001",
    topicName: "사람을 끌어당기는 사람인가",
    categoryGroup: "RELATION",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "합 개수 · 인성 · 비겁",
    note: null,
  },
  {
    topicId: "RELATION_002",
    topicName: "귀인이 되는 사람의 특징",
    categoryGroup: "RELATION",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "귀인계 신살 · 용신 오행",
    note: "scene 매핑 예외 — topic_id 접두어 규칙과 무관하게 'guin' 전용(docs/01 §1-4)",
  },
  {
    topicId: "RELATION_003",
    topicName: "사람 때문에 손해 보기 쉬운 상황",
    categoryGroup: "RELATION",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "겁재 · 재성 인접 충·해 (MONEY_003과 중복 페어)",
    note: "MONEY_003과 중복 페어",
  },
  {
    topicId: "RELATION_004",
    topicName: "필요한 인간관계의 거리",
    categoryGroup: "RELATION",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "합/충 비율 · 식상",
    note: null,
  },
  {
    topicId: "RELATION_005",
    topicName: "사람을 판단할 때 놓치기 쉬운 부분",
    categoryGroup: "RELATION",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "편인 · 일지 지장간",
    note: null,
  },
  // ── LOVE (연애·인연) ──
  {
    topicId: "LOVE_001",
    topicName: "먼저 좋아하는가, 좋아하게 만드는가",
    categoryGroup: "LOVE",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "식상 vs 관성 · 일지",
    note: null,
  },
  {
    topicId: "LOVE_002",
    topicName: "연애에서 반복하기 쉬운 패턴",
    categoryGroup: "LOVE",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "일지 합·충 · 편성 십신 · 지장간",
    note: null,
  },
  {
    topicId: "LOVE_003",
    topicName: "잘 맞는 인연의 특징",
    categoryGroup: "LOVE",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "일지 오행 · 용신·희신 (confidence 가드레일)",
    note: null,
  },
  {
    topicId: "LOVE_004",
    topicName: "배우자와 함께할 때 좋아지는 운",
    categoryGroup: "LOVE",
    isTiming: false,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "일지 오행=용신/희신 (특이 조건 — 아니면 미노출)",
    note: null,
  },
  {
    topicId: "LOVE_005",
    topicName: "늦게 만날수록 좋은 인연",
    categoryGroup: "LOVE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "배우자성 후반 대운 유입 (특이 조건)",
    note: "시기형",
  },
  {
    topicId: "LOVE_006",
    topicName: "결혼 적령기라 불리는 흐름",
    categoryGroup: "LOVE",
    isTiming: true,
    isFallback: false,
    releasePhase: 2,
    requiredFacts: "배우자성 대운 · 도화",
    note: "시기형",
  },
  // ── LIFE (인생 흐름) — LIFE_005는 지시서에 없음(결번) ──
  {
    topicId: "LIFE_001",
    topicName: "인생의 방향이 크게 바뀌는 시기",
    categoryGroup: "LIFE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "대운 전환점 · 대운 지지 충 (A10 근거)",
    note: "시기형",
  },
  {
    topicId: "LIFE_002",
    topicName: "늦게 시작할수록 강해지는 영역",
    categoryGroup: "LIFE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "후반 대운 용신 · 십이운성 상승",
    note: "시기형",
  },
  {
    topicId: "LIFE_003",
    topicName: "후반 인생에서 중요해지는 흐름",
    categoryGroup: "LIFE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "시주 · 후반 대운 용신",
    note: "시기형",
  },
  {
    topicId: "LIFE_004",
    topicName: "지금 시기에 주목해야 할 흐름",
    categoryGroup: "LIFE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "현재 대운+세운 vs 용신 (B01/B10 근거)",
    note: "시기형",
  },
  {
    topicId: "LIFE_006",
    topicName: "인생에서 가장 힘이 실리는 10년",
    categoryGroup: "LIFE",
    isTiming: true,
    isFallback: false,
    releasePhase: 1,
    requiredFacts: "대운 배열 최고점 (B08 근거)",
    note: "시기형",
  },
];

// [무결성 검증] 29종(폴백1+MONEY6+TALENT5+PERSONALITY1+RELATION5+LOVE6+LIFE5=29) 확인.
if (TOPIC_CATALOG_SEED.length !== 29) {
  throw new Error(
    `TOPIC_CATALOG_SEED 길이가 29가 아님(실제 ${TOPIC_CATALOG_SEED.length}) — 지시서 §7과 불일치`
  );
}

/** 시기형(isTiming) 주제 전체 — 세션당 최대 1개만 후보에 포함(지시서 §7 각주, topic-engine.ts에서 강제). */
export const TIMING_TOPIC_IDS = TOPIC_CATALOG_SEED.filter((t) => t.isTiming).map(
  (t) => t.topicId
);
