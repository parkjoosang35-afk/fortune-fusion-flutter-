// [TK-6 "출생시각 고지" 검증] applyBirthTimeUnknownGuard()가 실제 engine facts에서
// 시주 파생 필드를 제거하면, topic-engine.ts의 selectTopics()가 LIFE_003(시주 필수)을
// 후보 풀에서 자동으로 제외하는지 end-to-end로 검증한다. 실제 saju_engine이 반환한
// facts JSON(/tmp/facts_known.json, 시간 입력 있음)을 그대로 입력으로 사용한다.
import fs from "node:fs";
import { applyBirthTimeUnknownGuard } from "../src/lib/saju-renewal/saju-facts-time-guard";
import { selectTopics } from "../src/lib/saju-renewal/topic-engine";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const rawFacts = JSON.parse(fs.readFileSync("/tmp/facts_known.json", "utf-8")) as SajuV3Facts;

console.log("원본 facts.pillars.hour:", JSON.stringify(rawFacts.pillars?.hour));

// 1) birthTimeUnknown=false — 기존 동작 그대로(원본과 동일 객체 반환 확인)
const kept = applyBirthTimeUnknownGuard(rawFacts, false);
if (kept !== rawFacts) throw new Error("FAIL: birthTimeUnknown=false인데 새 객체를 반환함(불필요한 복사)");
console.log("✅ birthTimeUnknown=false → 원본 그대로 반환");

// 2) birthTimeUnknown=true — 시주 파생 필드 제거 확인
const stripped = applyBirthTimeUnknownGuard(rawFacts, true);
if (stripped.pillars?.hour !== null) throw new Error("FAIL: pillars.hour가 null로 제거되지 않음");
if (stripped.ten_gods?.hour_gan !== undefined) throw new Error("FAIL: ten_gods.hour_gan이 제거되지 않음");
if (stripped.ten_gods?.hour_zhi !== undefined) throw new Error("FAIL: ten_gods.hour_zhi가 제거되지 않음");
if (stripped.twelve_stages?.hour !== undefined) throw new Error("FAIL: twelve_stages.hour가 제거되지 않음");
// 원본은 변형되지 않아야 함(순수 함수)
if (rawFacts.pillars?.hour === null) throw new Error("FAIL: 원본 facts가 변형됨(순수 함수 위반)");
console.log("✅ birthTimeUnknown=true → 시주 파생 필드 전부 제거, 원본은 불변");

// 3) selectTopics 연동 — LIFE_003이 시간 모름일 때 후보에서 사라지는지 확인
function topicIdsIn(result: ReturnType<typeof selectTopics>): string[] {
  return [result.todayTopic.topicId, ...result.nextCandidates.map((c) => c.topicId)];
}

const now = new Date("2026-01-01T00:00:00Z");
const withHour = selectTopics({ facts: rawFacts, exposureHistory: [], now });
const withoutHour = selectTopics({ facts: stripped, exposureHistory: [], now });

console.log("시간 있음 후보:", topicIdsIn(withHour));
console.log("시간 모름 후보:", topicIdsIn(withoutHour));

if (topicIdsIn(withoutHour).includes("LIFE_003")) {
  throw new Error("FAIL: 시간 모름인데 LIFE_003(시주 필수 주제)이 후보에 포함됨");
}
console.log("✅ 시간 모름 → LIFE_003이 후보 풀에서 자동 제외됨(topic-engine.ts 수정 없이 동작)");

console.log("\n✅ TK-6(출생시각 고지) applyBirthTimeUnknownGuard ↔ selectTopics 연동 검증 통과");
