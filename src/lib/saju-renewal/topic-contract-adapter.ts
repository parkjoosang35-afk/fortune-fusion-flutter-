// [정통사주 리뉴얼 v1.0] Contract Adapter — topic-engine.ts의 내부 출력(TopicCandidateResult)을
// 디자인팀 확정 계약(design_handoff_jeongtong_saju_v3/docs/11_API_계약서.md)의
// 화면 응답 형태(TopicCard / key_facts)로 "변환"만 하는 파일.
//
// [원칙 — 2025 진행 승인 지시 §5 "Adapter의 역할은 변환입니다. 여기에 사주 판단
// 로직을 새로 추가하지 마세요"] 이 파일은 다음만 한다:
//   1) topic_id → scene 매핑 조회(디자인팀이 이미 확정한 표를 그대로 옮긴 것, 새 판단 없음)
//   2) 엔진이 이미 계산해 내려준 day_master.element / yongshin.yong(한글 오행)을
//      ElementCode(영문)로 1:1 치환(변환표만 있고 조건 분기·임계값 없음)
//   3) TopicCandidateResult → TopicCard 필드명 치환
// "어떤 Fact가 어떤 주제의 근거인가"를 새로 해석하는 로직(예: 카테고리별 전용 오행
// 산출)은 추가하지 않는다 — 그런 추가 판단이 필요하면 topic-evidence.ts(Topic Engine
// 레이어)에서 EvidenceCheck에 이미 계산된 값을 실어 보내는 방식으로 확장해야 하며,
// 이 Adapter가 사후적으로 재해석하면 안 된다(엔진/Topic Engine과 Adapter의 책임 분리).

import type { TopicCandidateResult } from "./topic-engine";
import type { SajuV3Facts } from "./saju-facts-types";

/** docs/11_API_계약서.md 공통 타입 — 화면(Flutter)과 이미 공유된 영문 오행 코드.
 * [출처] flutter_app `saju_dawn_tokens.dart`의 `enum SajuDawnElement { wood, fire,
 * earth, metal, water }`와 동일 명칭. 새 명칭을 만들지 않고 기존 확정 명칭을 그대로 사용. */
export type ElementCode = "wood" | "fire" | "earth" | "metal" | "water";

/** docs/01_디자인토큰.md §1-4 "주제군 조명(scene tint)" 확정 5종. */
export type SceneCode = "money" | "talent" | "love" | "life" | "guin";

/** docs/11_API_계약서.md §2 TopicCard. */
export interface TopicCard {
  topic_id: string;
  scene: SceneCode;
  title: string;
  is_timing: boolean;
  evidence_fact_keys: string[];
}

/**
 * [한글 오행 → ElementCode 변환표] saju_engine(`saju_facts.py`)이 내려주는 오행은
 * 한글 1글자(목/화/토/금/수)다. 엔진 코드는 수정하지 않고, 이 변환표로만 영문 코드로
 * 바꾼다(그 외 로직 없음 — 순수 치환).
 */
const KOREAN_TO_ELEMENT_CODE: Record<string, ElementCode> = {
  목: "wood",
  화: "fire",
  토: "earth",
  금: "metal",
  수: "water",
};

export function toElementCode(koreanElement: string | undefined | null): ElementCode | null {
  if (!koreanElement) return null;
  return KOREAN_TO_ELEMENT_CODE[koreanElement] ?? null;
}

/**
 * [Scene 매핑표 — docs/01_디자인토큰.md §1-4 확정본]
 * 매핑 규칙: topic_id 접두어로 결정하되 RELATION_002는 예외로 guin.
 *
 * ⚠️ [PERSONALITY_001 — 2025 진행 승인 지시 §1에 따라 "미확정" 상태로 관리]
 * docs/01 §1-4 scene 매핑표에는 PERSONALITY 접두어가 없고, docs/10_개발자보고서_회신.md
 * §6에서 디자인팀 스스로 "29종 카탈로그에 다른 접두어가 있으면 회신 바람 → 매핑 추가"라고
 * 명시한 미해결 항목이다. 지시에 따라 이 표에 PERSONALITY_001 키를 "절대 추가하지 않는다"
 * (예: life로 임시 배정 금지). getTopicScene()이 undefined를 반환하도록 두어, 호출부
 * (topics/select, STEP 3)가 scene 미확정 토픽을 선정 풀에서 원천 배제하도록 강제한다.
 * TODO(디자인 확인 대기): 디자인팀 회신으로 PERSONALITY_001의 scene이 확정되면, 이 표에
 * 키를 추가하고 PERSONALITY_SCENE_PENDING_TOPIC_IDS에서 제거할 것.
 */
const EXPLICIT_SCENE_OVERRIDES: Record<string, SceneCode> = {
  // RELATION_002만 유일한 접두어 규칙 예외(docs/01 §1-4, topic-catalog-data.ts의 note와 동일 근거).
  RELATION_002: "guin",
};

/** topic_id 접두어 → scene 기본 매핑(docs/01 §1-4). PERSONALITY는 의도적으로 없음. */
const PREFIX_TO_SCENE: Record<string, SceneCode> = {
  MONEY: "money",
  TALENT: "talent",
  LOVE: "love",
  RELATION: "love", // docs/01 §1-4: scene.love 목록에 RELATION_001,003~005 포함(예외는 위 override의 RELATION_002만)
  LIFE: "life",
};

/** scene이 아직 디자인팀에 의해 확정되지 않은 topic_id 목록(현재는 PERSONALITY_001뿐).
 * topics/select API(STEP 3)는 이 목록에 포함된 topic_id를 후보 풀에서 반드시 제외해야 한다. */
export const SCENE_UNRESOLVED_TOPIC_IDS: readonly string[] = ["PERSONALITY_001"];

/**
 * topic_id로부터 SceneCode를 조회한다. 매핑이 없는 경우(현재는 PERSONALITY_001만)
 * undefined를 반환한다 — 호출부가 반드시 이 undefined를 "화면에 노출하지 않음"으로
 * 처리해야 한다(임시값 대입 금지, 2025 진행 승인 지시 §1).
 */
export function getTopicScene(topicId: string): SceneCode | undefined {
  if (EXPLICIT_SCENE_OVERRIDES[topicId]) return EXPLICIT_SCENE_OVERRIDES[topicId];
  const prefix = topicId.split("_")[0];
  return PREFIX_TO_SCENE[prefix];
}

/**
 * TopicCandidateResult(topic-engine.ts 내부 출력) → TopicCard(docs/11 계약) 변환.
 * scene이 미확정(undefined)인 토픽에 대해 호출하면 에러를 던진다 — 호출부가 이미
 * SCENE_UNRESOLVED_TOPIC_IDS로 필터링을 마친 뒤에만 이 함수를 호출해야 하며, 혹시라도
 * 필터링을 빠뜨렸을 때 "life 같은 임시값으로 조용히 통과"되는 사고를 방지하기 위해
 * 명시적으로 fail-fast한다.
 */
export function toTopicCard(result: TopicCandidateResult): TopicCard {
  const scene = getTopicScene(result.topicId);
  if (!scene) {
    throw new Error(
      `[topic-contract-adapter] topic_id=${result.topicId}의 scene이 미확정 상태입니다. ` +
        `임시값을 대입하지 않고 상위 호출부에서 SCENE_UNRESOLVED_TOPIC_IDS로 사전 제외해야 합니다.`
    );
  }
  return {
    topic_id: result.topicId,
    scene,
    title: result.title,
    is_timing: result.isTiming,
    evidence_fact_keys: result.evidenceFactKeys,
  };
}

/**
 * [key_facts 추출 — docs/11 §2 "03-8 중앙 집결 오행 1~2개 (first_topic 근거 기준)"]
 * 새로운 사주 판단 로직을 추가하지 않기 위해(2025 진행 승인 지시 §5), 엔진이 이미
 * 계산해 응답에 담아 보내는 두 오행만 사용한다:
 *   - day_master.element: 일간 오행(모든 해석의 기준점, 모든 주제에 공통)
 *   - yongshin.yong: 용신 오행(명식이 필요로 하는 핵심 오행, 엔진이 이미 산출)
 * 주제별로 "어떤 Fact가 그 주제의 핵심 오행인가"를 새로 매핑하는 것은 Topic Engine의
 * evidence 판정 로직(topic-evidence.ts) 확장 영역이며, 이 Adapter에서 임의로
 * 결정하지 않는다. 운영 중 주제별 세분화가 필요해지면 topic-evidence.ts의
 * EvidenceCheck에 `element?: string` 필드를 추가해 평가자가 직접 산출하게 하고, 이
 * 함수는 그 값을 단순 치환만 하도록 확장하는 것이 올바른 순서다.
 */
export function extractKeyFacts(facts: SajuV3Facts): ElementCode[] {
  const candidates = [facts.day_master?.element, facts.yongshin?.yong];
  const result: ElementCode[] = [];
  for (const kr of candidates) {
    const code = toElementCode(kr);
    if (code && !result.includes(code)) result.push(code);
    if (result.length >= 2) break;
  }
  return result;
}
