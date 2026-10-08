// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-3/TK-10] finding-detector.ts 개발 단계 수동
// 검증 스크립트. DB/Next.js 없이 순수 함수 detectFindings()/findForTopic()만 호출해
// 실제 /saju/v3/facts 샘플 응답으로 finding 검출 로직이 정상 동작하는지 확인한다.
// 운영 코드에서 import되지 않으며, dev-test-topic-engine.ts와 동일한 패턴을 따른다.
import { readFileSync } from "fs";
import { detectFindings, findForTopic } from "../src/lib/saju-renewal/finding-detector";
import { buildDaeunTimeline, renderDaeunTableMarkdown, renderAnchorSentence } from "../src/lib/saju-renewal/daeun-timeline";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const factsRaw = readFileSync("/tmp/sample_facts.json", "utf-8");
const facts: SajuV3Facts = JSON.parse(factsRaw);

console.log("=== 1) 대운 타임라인(C2/C5) ===");
const timeline = buildDaeunTimeline(facts);
console.log(renderDaeunTableMarkdown(timeline));
console.log("\n앵커 문장:", renderAnchorSentence(timeline));

console.log("\n=== 2) findings 전체 검출 ===");
const findings = detectFindings(facts);
console.log(JSON.stringify(findings, null, 2));

console.log("\n=== 3) 재요청 불변성(결정론) 검증 ===");
const findings2 = detectFindings(facts);
const deterministic = JSON.stringify(findings) === JSON.stringify(findings2);
console.log("동일 입력 → 동일 출력?", deterministic);
if (!deterministic) {
  console.error("❌ 결정론 위반 — finding-detector.ts를 점검해야 합니다.");
  process.exit(1);
}

console.log("\n=== 4) findForTopic() — 시기형 topicId 매핑 ===");
for (const topicId of ["LIFE_001", "MONEY_004", "LOVE_005", "PERSONALITY_001", "NONEXISTENT_999"]) {
  const f = findForTopic(topicId, facts);
  console.log(`${topicId} ->`, f ? `${f.code} (${f.span.ganzhi}, ${f.span.age_korean[0]}-${f.span.age_korean[1]}세, tense=${f.tense})` : "null(전제 없음)");
}

console.log("\n=== 5) §4-C1 facts-only 가드 — luck_pillars 없는 facts ===");
const noLuckFacts: SajuV3Facts = { ...facts, luck_pillars: [] };
const emptyFindings = detectFindings(noLuckFacts);
console.log("luck_pillars=[] 일 때 findings 개수:", emptyFindings.length, "(sinsal만 남을 수 있음)");

console.log("\n=== 6) HEALTH_RISK 스케일 검증(0~100) ===");
const extremeFacts: SajuV3Facts = { ...facts, day_master_strength_score: 85 };
const extremeFindings = detectFindings(extremeFacts);
const hasHealth = extremeFindings.some((f) => f.code === "HEALTH_RISK");
console.log("score=85일 때 HEALTH_RISK 검출됨?", hasHealth);

console.log("\n✅ finding-detector.ts 전체 검증 통과");
