// [정통사주 리뉴얼 v2.0 — TK-6 "출생시각 고지"(§6.4 원인 D)]
//
// [문제] saju_engine(`/saju/v3/facts`)은 hour 입력이 없으면 항상 기본값(12:00)으로
// 시주를 계산해 반환하며, 이 값이 "실제 입력값"인지 "추정값"인지 구분하는 어떤
// 플래그도 제공하지 않는다(직접 curl 테스트로 확인됨). 즉 "시간 모름" 상태 추적은
// engine이 아니라 admin_web 레이어(UserProfile.birthTimeUnknown)의 책임이다.
//
// [기존 설계 문서상의 계약] docs/03_화면명세.md line 104:
//   "서버 전달: birth_time = null, time_unknown = true → 시주 미사용 주제로
//   자동 조정(서버)."
// docs/07_예외_엣지케이스.md E-15: "...시주 미사용 주제만 후보...".
// PDF saju-handoff-spec §6.4: "출생시각(시진) — 권장 — 시주·대운수 정밀도 —
// 시주 생략 가능, '미반영' 고지."
//
// [설계] birthTimeUnknown=true일 때 facts에서 "시주로부터 파생된 필드"를 제거해
// 마치 엔진이 애초에 그 값을 몰랐던 것처럼 만든다(engine 자체는 수정하지 않음 —
// 1장 원칙 "계산 엔진 코드는 건드리지 않는다" 준수). 이렇게 하면:
//
//   1) topic-evidence.ts의 evalLIFE_003 `hour_pillar_present` 체크
//      (`!!facts.pillars?.hour`)가 자동으로 false가 되어, topic-engine.ts의
//      조건 검증(충족 근거 ≥2)을 통과하지 못하므로 LIFE_003("시주 · 후반 대운
//      용신" 요구)이 후보 풀에서 자동 제외된다 — topic-engine.ts/
//      topic-catalog-data.ts를 전혀 수정할 필요가 없다.
//   2) bazi-elements.ts의 countTenGodGroup()이 ten_gods의 hour_gan/hour_zhi
//      슬롯을 제거한 상태로 비율(ratio)을 재계산하므로, "십신 편중(≥35%)" 같은
//      조건이 시주를 포함한 7슬롯이 아니라 실제로 알고 있는 5슬롯만으로
//      정확히 계산된다.
//   3) interpret-prompt.ts의 buildFactDigest()가 facts.pillars를 그대로 복사해
//      LLM 프롬프트에 넣으므로, pillars.hour=null이면 LLM이 시주를 "FACTS에
//      없는 값"으로 인지한다(§4-C1 "FACTS에 없는 것을 절대 생성하지 않는다"
//      원칙에 따라 자연히 언급을 피하게 된다 — 별도 프롬프트 수정 불필요).
//
// [applyBirthTimeUnknownGuard를 호출하는 곳] topics/select/route.ts와
// interpret/route.ts, 양쪽 모두 getSajuFacts() 직후 / selectTopics() ·
// validateTopicForInterpret() · buildInterpretPrompt() 호출 "직전"에 적용한다.
// SajuFactsCache 자체(캐시된 원본 facts)는 건드리지 않는다 — 이 함수는 순수
// 함수로 원본을 변형하지 않고 새 객체를 반환한다(다른 요청/사용자가 같은
// birthKey로 캐시를 다시 읽을 때 영향받지 않도록).
import type { SajuV3Facts, SajuV3TenGods } from "./saju-facts-types";

function stripHourFromTenGods(tenGods: SajuV3TenGods | undefined): SajuV3TenGods | undefined {
  if (!tenGods) return tenGods;
  const clone: SajuV3TenGods = { ...tenGods };
  delete clone.hour_gan;
  delete clone.hour_zhi;
  return clone;
}

/**
 * birthTimeUnknown=true일 때 facts에서 시주(hour pillar) 파생 필드를 제거한
 * 새 facts 객체를 반환한다. birthTimeUnknown=false면 입력을 그대로 반환한다
 * (불필요한 복사를 피함 — 대다수 요청은 출생시각을 알고 있으므로 이 경로가
 * 핫패스다).
 */
export function applyBirthTimeUnknownGuard(
  facts: SajuV3Facts,
  birthTimeUnknown: boolean
): SajuV3Facts {
  if (!birthTimeUnknown) return facts;

  return {
    ...facts,
    pillars: facts.pillars ? { ...facts.pillars, hour: null } : facts.pillars,
    ten_gods: stripHourFromTenGods(facts.ten_gods),
    twelve_stages: facts.twelve_stages
      ? { ...facts.twelve_stages, hour: undefined }
      : facts.twelve_stages,
    zhi_qigan: facts.zhi_qigan ? { ...facts.zhi_qigan, hour: undefined } : facts.zhi_qigan,
  };
}
