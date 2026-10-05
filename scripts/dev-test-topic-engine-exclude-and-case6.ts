// [정통사주 리뉴얼 v1.0 — STEP 3] topic-engine.ts의 신규 excludeTopicIds 파라미터 +
// CASE 6(조건 충족 Topic이 2개뿐일 때 2개만 반환, 임의 Topic으로 채우지 않음)
// 단위 검증. DB/Next.js 없이 순수 함수 selectTopics()만 호출한다. 운영 코드에서
// import되지 않으며, 완성 후 삭제하지 않고 회귀 점검용으로 보존한다.
import { TOPIC_CATALOG_SEED } from "../src/lib/saju-renewal/topic-catalog-data";
import { TOPIC_EVIDENCE_EVALUATORS } from "../src/lib/saju-renewal/topic-evidence";
import { selectTopics } from "../src/lib/saju-renewal/topic-engine";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";
import { readFileSync } from "fs";

const full: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));
const scarce: SajuV3Facts = {
  pillars: full.pillars,
  day_master: full.day_master,
  yongshin: full.yongshin,
  ten_gods: full.ten_gods,
  day_master_strength_score: full.day_master_strength_score,
};

// 전체 29종 중 실제로 "조건을 충족하는" 비폴백 Topic 전부를 나열(디버그)
const passing: string[] = [];
for (const t of TOPIC_CATALOG_SEED) {
  if (t.isFallback) continue;
  if (t.releasePhase !== 1) continue;
  const ev = TOPIC_EVIDENCE_EVALUATORS[t.topicId];
  if (!ev) continue;
  const checks = ev(scarce);
  const satisfied = checks.filter((c) => c.satisfied);
  const required = Math.min(2, checks.length);
  if (satisfied.length >= required && required > 0) passing.push(t.topicId);
}
console.log("조건 충족 비폴백 Topic 전체:", passing, "(개수:", passing.length, ")");

// passing 중 2개만 남기고 나머지 전부 excludeTopicIds에 넣는다.
const keep = passing.slice(0, 2);
const excludeTopicIds = passing.filter((id) => !keep.includes(id));
console.log("유지할 2개:", keep, "/ 제외할 나머지:", excludeTopicIds);

const result = selectTopics({
  facts: scarce,
  exposureHistory: [],
  now: new Date("2026-10-04T00:00:00Z"),
  excludeTopicIds,
});
console.log("\n[CASE 6] today:", result.todayTopic.topicId);
console.log("[CASE 6] candidates:", result.nextCandidates.map((c) => c.topicId));
console.log("[CASE 6] candidates 개수:", result.nextCandidates.length);

// today가 폴백(LIFE_000)이면 candidates에 keep 2개가 전부 들어가야 함(정확히 2개)
if (result.todayTopic.topicId === "LIFE_000" && result.nextCandidates.length === keep.length) {
  console.log(`✅ CASE 6 통과: 조건 충족 Topic이 ${keep.length}개뿐일 때 ${keep.length}개만 반환(임의 Topic으로 채우지 않음)`);
} else {
  console.log("❌ CASE 6 실패: 예상과 다른 결과");
  process.exit(1);
}
