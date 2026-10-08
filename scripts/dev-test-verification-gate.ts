// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-2] interpret-verification-gate.ts 개발 단계
// 수동 검증 스크립트. saju-handoff-spec.pdf §8.3 데모(make_engine/BAD/GOOD 텍스트)를
// 그대로 재현해 §8.4 "실행 결과(검증 케이스)"와 동일한 위반이 나오는지 확인한다.
//
// [PDF §8.3 데모 엔진 값 그대로]
//   birth_year=1972, day_pillar=甲戌, current_year=2026, yongsin=[木,水]
//   daeun: 乙巳(1999-2008,28-37) 丙午(2009-2018,38-47) 丁未(2019-2028,48-57)
//          戊申(2029-2038,58-67) 己酉(2039-2048,68-77) 庚戌(2049-2058,78-87)
// → 이 데모 기준 "현재(2026년)"는 丁未 대운(2019~2028) 구간, 세는나이 55세.
import { runVerificationGate, formatViolationsForFeedback, hasBlockingViolations } from "../src/lib/saju-renewal/interpret-verification-gate";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";
import type { Finding } from "../src/lib/saju-renewal/finding-detector";

// PDF 데모의 daeun 배열을 SajuV3Facts.luck_pillars 형태로 변환(현재 나이는
// facts.current_age로 별도 공급 — daeun-timeline.ts가 그 값으로 tense를 계산).
const demoFacts: SajuV3Facts = {
  pillars: { day: { gan: "甲", zhi: "戌", kr: "갑술" } },
  yongshin: { yong: "목", hee: "수", gi: undefined, gu: undefined },
  current_age: 55,
  luck_pillars: [
    { start_age: 28, start_year: 1999, gan_zhi: "乙巳", gan_zhi_kr: "을사" },
    { start_age: 38, start_year: 2009, gan_zhi: "丙午", gan_zhi_kr: "병오" },
    { start_age: 48, start_year: 2019, gan_zhi: "丁未", gan_zhi_kr: "정미" },
    { start_age: 58, start_year: 2029, gan_zhi: "戊申", gan_zhi_kr: "무신" },
    { start_age: 68, start_year: 2039, gan_zhi: "己酉", gan_zhi_kr: "기유" },
    { start_age: 78, start_year: 2049, gan_zhi: "庚戌", gan_zhi_kr: "경술" },
  ],
};

const topic = { topicId: "LIFE_001", premiseRef: null, timeScoped: true, gateProfile: "time_scoped" as const };
const findings: Finding[] = [];

console.log("=== BAD 텍스트(PDF §8.3 데모 그대로) ===");
const BAD =
  "당신은 원래 기운이 충만한 사람인데, 38세부터 48세까지의 대운 흐름이 본래의 강함을 극대화시킵니다. " +
  "이 10년이 인생에서 가장 힘이 실리는 시기입니다. 당신 사주가 필요로 하는 金 기운이 충분히 공급됩니다.";
const badViolations = runVerificationGate({ facts: demoFacts, topic, findings, text: BAD });
console.log(JSON.stringify(badViolations, null, 2));
console.log("차단 여부:", hasBlockingViolations(badViolations));

console.log("\n기대(PDF §8.4): YONGSIN_HALLUCINATION('金'은 엔진 용신에 없음), ANCHOR_DAEUN_MISSING, ANCHOR_AGE_MISSING");
const badCodes = new Set(badViolations.map((v) => v.code));
const expectBad = ["YONGSIN_HALLUCINATION", "ANCHOR_DAEUN_MISSING", "ANCHOR_AGE_MISSING"];
const badOk = expectBad.every((c) => badCodes.has(c as never));
console.log("BAD 케이스 기대 위반 3종 모두 검출됨?", badOk);

console.log("\n=== GOOD 텍스트(PDF §8.3 데모 그대로) ===");
const GOOD =
  "지금 당신은 55세, 정미(丁未) 대운(2019~2028) 구간에 있습니다. " +
  "과거 38~48세의 병오(丙午) 대운에서 쌓은 성과가 지금의 기반입니다. " +
  "앞으로 무신(戊申) 대운(2029~2038)으로 넘어갑니다. 당신 사주가 필요로 하는 목(木)·수(水) 기운을 보충하세요.";
const goodViolations = runVerificationGate({ facts: demoFacts, topic, findings, text: GOOD });
console.log(JSON.stringify(goodViolations, null, 2));
console.log("기대(PDF §8.4): (없음) → 게시 통과");
console.log("GOOD 케이스 위반 0건?", goodViolations.length === 0);

console.log("\n=== feedback 포맷 샘플 ===");
console.log(formatViolationsForFeedback(badViolations).join("\n"));

if (!badOk || goodViolations.length !== 0) {
  console.error("\n❌ PDF §8.4 레퍼런스 결과와 불일치 — interpret-verification-gate.ts를 점검해야 합니다.");
  process.exit(1);
}
console.log("\n✅ §8.3/§8.4 레퍼런스 케이스 재현 통과");

console.log("\n=== 추가 검증: SINSAL_HALLUCINATION(최초 구현, §5.5) ===");
const sinsalFacts: SajuV3Facts = { ...demoFacts, sinsal: ["天乙貴人(천을귀인)"] };
const sinsalTopic = { topicId: "SINSAL_001", premiseRef: null, timeScoped: false, gateProfile: "sinsal" as const };
const sinsalGoodText = "당신 사주에는 천을귀인이 있습니다.";
const sinsalBadText = "당신 사주에는 화개가 강하게 자리잡고 있습니다.";
console.log("허용된 신살만 언급(위반 0건 기대):", runVerificationGate({ facts: sinsalFacts, topic: sinsalTopic, findings: [], text: sinsalGoodText }));
console.log("엔진에 없는 신살 언급(SINSAL_HALLUCINATION 기대):", runVerificationGate({ facts: sinsalFacts, topic: sinsalTopic, findings: [], text: sinsalBadText }));

console.log("\n=== 추가 검증: TOPIC_PREMISE_NOT_IN_FACTS / PREMISE_TENSE_MISMATCH(§5.6/§5.4) ===");
const premiseFinding: Finding = {
  finding_id: "F1",
  code: "STRONGEST_DAEUN",
  subject: "self",
  span: { ganzhi: "병오", from: 2009, to: 2018, age_korean: [38, 47] },
  strength: 0.95,
  tense: "past",
  evidence_refs: ["daeun[1]", "yongsin"],
};
const topicWithBadPremise = { topicId: "LIFE_001", premiseRef: "F_NOT_EXIST", timeScoped: true, gateProfile: "time_scoped" as const };
const v1 = runVerificationGate({ facts: demoFacts, topic: topicWithBadPremise, findings: [premiseFinding], text: GOOD });
console.log("premise_ref가 findings에 없을 때:", v1.filter((v) => v.code === "TOPIC_PREMISE_NOT_IN_FACTS"));

const topicWithGoodPremise = { topicId: "LIFE_001", premiseRef: "F1", timeScoped: true, gateProfile: "time_scoped" as const };
// [독립 텍스트] GOOD처럼 다른 finding의 "과거" 언급이 섞이지 않도록, 이 finding(F1,
// 병오, tense=past)만 단독으로 등장하는 텍스트로 시제 불일치를 명확히 재현한다.
const tenseMismatchText = "지금 당신은 55세, 정미(丁未) 대운(2019~2028) 구간에 있습니다. 병오 대운은 앞으로 더욱 강해질 것입니다.";
const v2 = runVerificationGate({ facts: demoFacts, topic: topicWithGoodPremise, findings: [premiseFinding], text: tenseMismatchText });
console.log("tense=past인데 '앞으로'로만 서술(PREMISE_TENSE_MISMATCH 기대):", v2.filter((v) => v.code === "PREMISE_TENSE_MISMATCH"));

const tenseOkText = "지금 당신은 55세, 정미(丁未) 대운(2019~2028) 구간에 있습니다. 병오 대운은 이미 지난 구간으로, 그 시절의 성과가 지금의 기반입니다.";
const v3 = runVerificationGate({ facts: demoFacts, topic: topicWithGoodPremise, findings: [premiseFinding], text: tenseOkText });
console.log("tense=past이고 '이미 지난'으로 올바르게 서술(위반 0건 기대):", v3.filter((v) => v.code === "PREMISE_TENSE_MISMATCH" || v.code === "TOPIC_PREMISE_NOT_IN_FACTS"));
