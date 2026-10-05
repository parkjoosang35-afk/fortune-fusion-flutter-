// [정통사주 리뉴얼 v1.0] Topic Engine 점수식 상수 — 최종지시서 §8 "Topic Engine 최종
// 규칙(구현 계약)" 원문을 그대로 반영한다.
//
//   score = 0.35E(근거강도) + 0.20I(흥미도) + 0.20T(시기관련성) + 0.15N(신규성)
//           + 0.10B(카테고리밸런스) − P(Fact 70% 중복 페널티)
//
// [7장 원칙 "숫자 하드코딩 금지"는 가중치 자체가 아니라 "코드 곳곳에 흩어진 매직넘버"를
// 금지하는 것이다 — §8은 가중치 0.35/0.20/0.20/0.15/0.10을 명시적으로 "상수 고정"이라고
// 못박았으므로, 이 값들은 placeholder가 아니라 지시서가 확정한 숫자다. "상수 고정(설정
// 파일 1곳)"이라는 문구가 요구하는 것은 정확히 이 파일 하나로 분리하는 것이며, 관리자
// 가중치 UI(동적 조정)는 2차 범위로 명시되어 있다 — 1차는 이 파일의 상수를 코드 전역에서
// import해서만 쓰고, topic-engine.ts 안에 숫자를 직접 적지 않는다.
export interface TopicScoringWeights {
  /** E: 근거강도 — 충족된 Fact 근거 개수 / 해당 주제의 전체 조건 개수 (0~1 정규화). */
  evidenceStrength: number;
  /** I: 흥미도 — 1차 MVP는 사용자별 관심사 데이터가 없어 전 주제 동일 기본값(§I_DEFAULT 참고). */
  interestLevel: number;
  /** T: 시기관련성 — 시기형 주제이면서 현재 대운/세운이 해당 Fact와 맞물릴 때 가중. */
  timingRelevance: number;
  /** N: 신규성 — topic_exposure_history 감쇠값(아래 EXPOSURE_DECAY_WEIGHTS)을 그대로 사용. */
  novelty: number;
  /** B: 카테고리밸런스 — 이번 선정 배치 안에서 같은 categoryGroup이 이미 나왔으면 감점. */
  categoryBalance: number;
}

/** §8 원문 그대로 — 1차 범위에서는 이 5개 가중치를 수정하지 않는다(2차: 관리자 UI). */
export const SCORING_WEIGHTS: TopicScoringWeights = {
  evidenceStrength: 0.35,
  interestLevel: 0.2,
  timingRelevance: 0.2,
  novelty: 0.15,
  categoryBalance: 0.1,
};

// [I 성분 기본값] §8은 I(흥미도)의 산출 방법을 별도로 정의하지 않았다(사용자 행동 로그
// 기반 흥미도 모델은 이번 범위 밖). 전 주제 동일한 중립값(0.5)을 사용해 I 성분이 주제
// 간 순위를 왜곡하지 않도록 한다 — 추후 사용자 선택 이력 기반 모델을 붙일 때 이 상수
// 하나만 교체하면 된다(다른 코드 변경 불필요).
export const DEFAULT_INTEREST_LEVEL = 0.5;

// [T 성분 기본값] 시기형이 아닌 주제는 "시기관련성" 자체가 성립하지 않으므로 중립값
// (0.5)을 쓰고, 시기형 주제는 조건 검증 단계에서 이미 "현재 대운/세운이 해당 Fact와
// 실제로 맞물리는지"를 확인했으므로(evidence 통과 = 시기 적중) 1.0을 부여한다.
export const TIMING_RELEVANCE_WHEN_MATCHED = 1.0;
export const TIMING_RELEVANCE_WHEN_NEUTRAL = 0.5;

// [N 성분 — 노출 이력 감쇠, §8 원문 그대로] "미노출 1.0 / 90일 0.7 / 30일 0.3 / 7일 0.05".
// 이 4개 숫자만이 지시서가 명시적으로 확정한 "노출 이력 가중치"다. 경계값 판정은
// "가장 최근 노출 시각 기준 경과일"을 아래 임계값과 비교해 내림차순(오래될수록 1.0에
// 가까움)으로 매칭한다.
export interface ExposureDecayRule {
  /** 이 일수"이상" 경과했을 때 적용되는 가중치. 배열은 내림차순(가장 오래된 것부터)으로 정렬. */
  minDaysElapsed: number;
  weight: number;
}

export const EXPOSURE_DECAY_WEIGHTS: ExposureDecayRule[] = [
  { minDaysElapsed: 90, weight: 0.7 },
  { minDaysElapsed: 30, weight: 0.3 },
  { minDaysElapsed: 7, weight: 0.05 },
  // 7일 미만(=매우 최근에 본 주제)은 지시서에 숫자가 없으나, 0.05보다 더 낮아야
  // "방금 본 이야기"가 다시 뜨지 않는다는 취지에 맞다 — 최소값 0으로 고정(사실상 제외).
  { minDaysElapsed: 0, weight: 0 },
];
/** 한 번도 노출되지 않은 주제(topic_exposure_history에 레코드 없음)의 신규성 = 1.0. */
export const NEVER_EXPOSED_NOVELTY = 1.0;

/**
 * [N 성분] 가장 최근 노출 시각으로부터 경과일을 계산해 §8 감쇠표에 매핑한다.
 * lastViewedAt이 없으면(=한 번도 안 봄) NEVER_EXPOSED_NOVELTY(1.0)을 반환한다.
 */
export function resolveNoveltyWeight(lastViewedAt: Date | null, now: Date = new Date()): number {
  if (!lastViewedAt) return NEVER_EXPOSED_NOVELTY;
  const elapsedDays = (now.getTime() - lastViewedAt.getTime()) / (1000 * 60 * 60 * 24);
  for (const rule of EXPOSURE_DECAY_WEIGHTS) {
    if (elapsedDays >= rule.minDaysElapsed) return rule.weight;
  }
  return 0;
}

// [B 성분] 이번 선정 배치(오늘의 주제 1 + 다음 후보 3~4) 안에서 같은 categoryGroup이
// 중복되면 다양성이 떨어진다 — "카테고리밸런스"의 취지를 "이미 뽑힌 카테고리는 감점"으로
// 구현한다. 지시서가 구체적 수치를 주지 않아, 바이너리(이미 등장=0.0 / 미등장=1.0)로
// 가장 단순하게 구현한다(2차에서 가중 조정 가능하도록 이 상수만 분리).
export const CATEGORY_BALANCE_FRESH = 1.0;
export const CATEGORY_BALANCE_DUPLICATE = 0.0;

// [P: Fact 70% 중복 페널티] §8 원문 "P(Fact 70% 중복 페널티)" — 중복 판정 임계값(70%)은
// 지시서가 명시했으나, 페널티의 "크기"는 숫자로 주어지지 않았다. 다른 가중치(E/I/T/N/B)가
// 모두 0~1 스케일이고 최댓값 합이 1.0이므로, 페널티도 동일 스케일에서 "상한선 점수를
// 무력화할 수 있는 크기"가 되도록 1.0으로 고정한다(= 70% 이상 중복이면 최종 점수가 거의
// 0 이하로 떨어져 사실상 후보에서 탈락). 운영 중 조정이 필요하면 이 상수 하나만 바꾼다.
export const DUPLICATE_FACT_OVERLAP_THRESHOLD = 0.7;
export const DUPLICATE_FACT_PENALTY_MAGNITUDE = 1.0;

// [조건 검증 단계] §8 "조건 검증(충족 근거 ≥2, confidence 가드레일)" — 이 "2"는 지시서가
// 숫자로 직접 확정한 값이다(placeholder 아님).
export const MIN_SATISFIED_EVIDENCE_COUNT = 2;

// [confidence 가드레일] §8은 "confidence 가드레일"이라는 표현만 두고 구체적 임계값은
// 명시하지 않았다(§9 LOVE_003 "confidence 가드레일" 비고도 동일). 각 증거 판정 함수
// (topic-evidence.ts)는 0~1 confidence를 반환하도록 설계했으므로, 평균 confidence가
// 이 값 미만이면 "충족 근거 ≥2"를 만족해도 근거가 약하다고 보고 주제를 탈락시킨다.
// 중립값 0.5(증거 판정 로직이 "이 조건은 확실하지 않지만 약하게 성립"이라고 보는
// 경계선)를 가드레일 기준으로 둔다 — 운영 중 조정 가능하도록 이 상수만 분리.
export const CONFIDENCE_GUARDRAIL_MIN = 0.5;

// [해석 가용성] §8 "해석용 Fact 3개 미만 주제는 점수 무관 후보 제외" — 역시 지시서 확정값.
export const MIN_EVIDENCE_FOR_INTERPRETATION = 3;

/** 오늘의 주제 1건 + 다음 후보 개수(3~4) — §8 "최종 1건 + 다음 후보 3~4". */
export const NEXT_CANDIDATES_MIN = 3;
export const NEXT_CANDIDATES_MAX = 4;
