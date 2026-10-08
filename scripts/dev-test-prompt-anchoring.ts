// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-1] interpret-prompt.ts의 C2/C5/C6 섹션이
// 실제로 조립되는지 확인하는 수동 검증 스크립트. dev-test-topic-engine.ts와 동일
// 패턴(DB/Next.js 없이 순수 함수만 호출).
import { readFileSync } from "fs";
import { buildInterpretPrompt, type PromptTopicInfo } from "../src/lib/saju-renewal/interpret-prompt";
import { findForTopic } from "../src/lib/saju-renewal/finding-detector";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const facts: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));

console.log("=== 1) isTiming=true 주제(LIFE_001) — 시간 앵커링 섹션 포함 기대 ===");
const timingTopic: PromptTopicInfo = { topicId: "LIFE_001", topicName: "인생의 흐름", categoryGroup: "LIFE", isTiming: true };
const premise = findForTopic(timingTopic.topicId, facts);
console.log("전제 finding:", premise ? `${premise.code} (${premise.span.ganzhi}, tense=${premise.tense})` : "null");

const built = buildInterpretPrompt({
  mode: "detail",
  topic: timingTopic,
  facts,
  evidence: { factKeys: [], notes: ["테스트 근거"] },
  topicSpecificSystemPrompt: "이 주제는 인생 전반의 흐름을 다룹니다.",
  premise,
});

const hasAnchorSection = built.systemPrompt.includes("[시간 앵커링");
const hasDaeunTable = built.systemPrompt.includes("| 대운 | 기간(연도)");
const hasPremiseBlock = premise ? built.systemPrompt.includes("[이 주제의 전제(premise)") : true;
const hasFindingSection = premise ? built.userPrompt.includes("[FINDING — 엔진이 검출한 전제") : true;

console.log("systemPrompt에 [시간 앵커링] 섹션 포함?", hasAnchorSection);
console.log("systemPrompt에 대운 타임라인 표 포함?", hasDaeunTable);
console.log("systemPrompt에 전제(premise) 블록 포함?", hasPremiseBlock);
console.log("userPrompt에 [FINDING] 섹션 포함?", hasFindingSection);

if (!hasAnchorSection || !hasDaeunTable || !hasPremiseBlock || !hasFindingSection) {
  console.error("❌ TK-1 기대 섹션 누락 — interpret-prompt.ts를 점검해야 합니다.");
  process.exit(1);
}

console.log("\n=== 2) isTiming=false 주제(PERSONALITY류) — 시간 앵커링 섹션 생략 기대 ===");
const noTimeTopic: PromptTopicInfo = { topicId: "PERSONALITY_002", topicName: "성격과 기질", categoryGroup: "PERSONALITY", isTiming: false };
const built2 = buildInterpretPrompt({
  mode: "detail",
  topic: noTimeTopic,
  facts,
  evidence: { factKeys: [], notes: [] },
  topicSpecificSystemPrompt: "이 주제는 성격을 다룹니다.",
  premise: null,
});
const noAnchorSection = !built2.systemPrompt.includes("[시간 앵커링");
const noFindingSection = !built2.userPrompt.includes("[FINDING");
console.log("isTiming=false일 때 [시간 앵커링] 섹션 생략됨?", noAnchorSection);
console.log("isTiming=false일 때 [FINDING] 섹션 생략됨?", noFindingSection);

if (!noAnchorSection || !noFindingSection) {
  console.error("❌ isTiming=false 주제에 불필요한 섹션이 포함됨 — 회귀 위험.");
  process.exit(1);
}

console.log("\n=== 3) 실제 조립된 앵커 문장 미리보기 ===");
const anchorLine = built.systemPrompt.split("\n").find((l) => l.startsWith('"지금 당신은'));
console.log(anchorLine);

console.log("\n✅ TK-1(interpret-prompt.ts C2/C5/C6+FINDING) 검증 통과");
