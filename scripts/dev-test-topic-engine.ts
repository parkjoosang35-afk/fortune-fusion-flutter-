// [정통사주 리뉴얼 v1.0] topic-engine.ts 개발 단계 수동 검증 스크립트.
// DB/Next.js 없이 순수 함수 selectTopics()만 호출해 실제 /saju/v3/facts 샘플
// 응답으로 파이프라인이 끝까지(폴백 보장·동점 규칙 포함) 정상 동작하는지 확인한다.
// 운영 코드에서 import되지 않으며, 완성 후 삭제하지 않고 회귀 점검용으로 보존한다.
import { readFileSync } from "fs";
import { selectTopics } from "../src/lib/saju-renewal/topic-engine";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const factsRaw = readFileSync("/tmp/sample_facts.json", "utf-8");
const facts: SajuV3Facts = JSON.parse(factsRaw);

console.log("=== 1) 노출 이력 없음(최초 방문) ===");
const result1 = selectTopics({ facts, exposureHistory: [], now: new Date("2026-10-04T00:00:00Z") });
console.log(JSON.stringify(result1, null, 2));

console.log("\n=== 2) 오늘의 주제를 과거(100일 전)에 봤던 이력 포함 ===");
const result2 = selectTopics({
  facts,
  exposureHistory: [
    { topicId: result1.todayTopic.topicId, viewedAt: new Date("2026-06-26T00:00:00Z") },
  ],
  now: new Date("2026-10-04T00:00:00Z"),
});
console.log("오늘의 주제(2회차):", result2.todayTopic.topicId, "score=", result2.todayTopic.score);
console.log(
  "다음 후보:",
  result2.nextCandidates.map((c) => `${c.topicId}(${c.score.toFixed(3)})`)
);

console.log("\n=== 3) 같은 입력 재호출 — 재요청 불변성(완전 결정론) 검증 ===");
const result3 = selectTopics({ facts, exposureHistory: [], now: new Date("2026-10-04T00:00:00Z") });
const deterministic = JSON.stringify(result1) === JSON.stringify(result3);
console.log("동일 입력 → 동일 출력?", deterministic);
if (!deterministic) {
  console.error("❌ 결정론 위반 — topic-engine.ts를 점검해야 합니다.");
  process.exit(1);
}

console.log("\n=== 4) 시기형 1개 하드 제한 검증 ===");
const timingIds = ["MONEY_004", "TALENT_004", "TALENT_005", "LOVE_005", "LIFE_001", "LIFE_002", "LIFE_003", "LIFE_004", "LIFE_006"];
const allPicked = [result1.todayTopic, ...result1.nextCandidates];
const timingPicked = allPicked.filter((c) => timingIds.includes(c.topicId));
console.log("선정된 시기형 개수:", timingPicked.length, "(기준: 0 또는 1)");
if (timingPicked.length > 1) {
  console.error("❌ 시기형 1개 제한 위반:", timingPicked.map((c) => c.topicId));
  process.exit(1);
}

console.log("\n✅ 전체 검증 통과");
