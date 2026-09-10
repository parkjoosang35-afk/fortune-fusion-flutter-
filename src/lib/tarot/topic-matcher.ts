// [신통방통 타로 65종 주제 연동 - §계획2 자유질문 자동매칭]
//
// 사용자가 topic을 명시하지 않고(레거시 general/love) 자유 문장으로
// 질문을 입력했을 때, `TOPIC_KEYWORDS` 사전을 기준으로 가장 근접한
// 65개 주제 중 하나를 찾아 반환한다. 매칭되는 주제가 없으면 null을
// 반환해 기존 레거시 경로(15장 DECK)를 그대로 타도록 한다 —
// "기존 60개 미검증 주제 + general/love 흐름은 절대 건드리지 않는다"
// 원칙을 자동매칭에도 동일하게 적용(매칭 실패 시 아무 영향 없음).
//
// 적용 위치: 서버 제출 시점(route.ts, POST 진입 직후) — 사용자가 타이핑
// 하는 동안 실시간으로 UI가 바뀌는 방식은 채택하지 않는다(입력 중
// 화면이 계속 바뀌면 혼란을 줄 수 있고, 서버 단일 판정이 카드추첨
// 시드/포지션 결정과 한 트랜잭션 내에서 일관되게 처리되기 때문).
import { TOPIC_KEYWORDS } from "./topic-keywords";

/** 공백/일부 특수문자를 제거해 조사가 붙어도 부분일치가 되도록 정규화한다. */
function normalize(text: string): string {
  return text.replace(/[\s?!.,~]/g, "");
}

/**
 * 자유질문 문장에서 65개 주제 중 하나를 자동으로 매칭한다.
 *
 * 알고리즘(키워드 기반, 단순 부분일치 스코어링):
 * 1) 질문 문장을 정규화(공백/구두점 제거)한다.
 * 2) 각 주제(topic)의 키워드 배열을 순회하며, 정규화된 질문에 해당
 *    키워드가 포함되어 있으면 그 주제의 점수를 1 올린다.
 * 3) 가장 높은 점수를 가진 주제를 반환한다. 동점이면 `TOPIC_KEYWORDS`
 *    선언 순서상 먼저 등장하는(=설계표상 앞쪽 그룹) 주제를 우선한다.
 * 4) 어떤 주제도 매칭되지 않으면(점수 0) null을 반환한다.
 *
 * @param question 사용자가 입력한 자유질문 원문
 * @returns 매칭된 topic_key 또는 null(매칭 실패 시 레거시 경로 유지)
 */
export function matchTopicFromQuestion(question: string): string | null {
  const normalized = normalize(question);
  if (!normalized) return null;

  let bestTopic: string | null = null;
  let bestScore = 0;

  for (const [topicKey, keywords] of Object.entries(TOPIC_KEYWORDS)) {
    let score = 0;
    for (const kw of keywords) {
      if (normalized.includes(normalize(kw))) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      bestTopic = topicKey;
    }
  }

  return bestScore > 0 ? bestTopic : null;
}
