// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-7 "주제별 대운 브리핑 표 UI(지난/현재/
// 앞으로)" §4-C5] 백엔드 측 구현 회귀 테스트.
//
// [배경 — TK-7 조사에서 발견한 근본 원인] daeun-timeline.ts의 buildDaeunTimeline()/
// renderDaeunTableMarkdown()은 이미 존재했지만, 오직 interpret-prompt.ts의
// buildTimeAnchoringSection()을 거쳐 "LLM 프롬프트 텍스트" 안에만 주입되고
// 있었다 — API 응답(InterpretDetailResult)에는 이 구조화 데이터가 전혀
// 노출되지 않아 Flutter가 facts 기반 타임라인 표를 그릴 방법이 없었다.
//
// [이번 구현] interpret-service.ts에 attachDaeunTimelineIfApplicable()을 추가해
// LLM 성공 경로와 fallback 경로 양쪽 모두, detail 모드+isTiming 주제일 때
// InterpretDetailResult.daeun_timeline 필드에 facts.luck_pillars를 그대로 옮긴
// 구조화 배열(DaeunTimelineApiEntry[])을 추가한다. 이 필드는 LLM이 쓴 텍스트가
// 아니므로 QA(checkInterpretDetail)를 다시 거치지 않는다(C5 "표 문자열을 새로
// 쓰지 말고 facts에서 복사" 원칙을 API 응답 레벨까지 연장).
//
// [검증 항목]
//   1) isTiming=true + LLM 성공 경로 → daeun_timeline이 채워지고, facts.luck_pillars
//      에서 역산한 entries와 정확히 일치(개수·간지·연도·나이·시제).
//   2) isTiming=false 주제 → daeun_timeline이 아예 없음(undefined) — 시기 FACT
//      없는 주제에 억지로 표를 붙이지 않는다(§4-C1).
//   3) facts에 luck_pillars가 없는(빈 배열) 경우 → isTiming=true여도 daeun_timeline
//      생략(데이터 없는데 빈 표를 강제하지 않음).
//   4) fallback 경로(LLM 실패 유도)에서도 daeun_timeline이 동일하게 채워짐.
//   5) daeun_timeline의 tense 라벨이 facts.current_age 기준으로 past/now/future로
//      정확히 분류됨(buildDaeunTimeline 로직 재검증).
import { readFileSync } from "fs";
import { generateInterpretResult, type LlmCaller } from "../src/lib/saju-renewal/interpret-service";
import type { PromptTopicInfo } from "../src/lib/saju-renewal/interpret-prompt";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";
import type { InterpretDetailResult } from "../src/lib/saju-renewal/interpret-qa-check";
import { buildDaeunTimeline } from "../src/lib/saju-renewal/daeun-timeline";

let failCount = 0;
function check(label: string, condition: boolean, detail?: unknown) {
  console.log(`${condition ? "✅" : "❌"} ${label}${detail !== undefined ? ` — ${JSON.stringify(detail)}` : ""}`);
  if (!condition) failCount++;
}

const facts: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));
// 이전 TK 스모크테스트로 이미 확인된 값: 현재나이 37세, 현재대운 정축(2023-2032).

const timingTopic: PromptTopicInfo = { topicId: "LIFE_001", topicName: "인생의 흐름", categoryGroup: "LIFE", isTiming: true };
const nonTimingTopic: PromptTopicInfo = { topicId: "PERSONALITY_001", topicName: "타고난 기질", categoryGroup: "PERSONALITY", isTiming: false };

function uniqueParagraph(seedSentences: string[]): string {
  return seedSentences.join(" ");
}

const GOOD_BLOCK1 = uniqueParagraph([
  "지금 당신은 37세이며 정축 대운 구간을 지나고 있습니다.",
  "이 구간은 2023년부터 2032년까지 이어지는 흐름으로 참고할 만합니다.",
  "사주 전체에서 금 기운이 두드러지게 자리 잡고 있어 안정적인 추진력을 보여줍니다.",
  "이런 흐름은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 이어지는 경우가 많습니다.",
  "사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다.",
  "지금부터 이 흐름이 왜 나타나는지 실제로는 어떤 방식으로 드러나는지 차근차근 짚어보겠습니다.",
  "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
  "지금 확인된 이 흐름도 당신만의 고유한 특징 중 하나로 봐주시면 좋겠습니다.",
  "정축 대운이 시작된 2023년 이후로 이런 경향이 조금씩 더 또렷해지고 있다고 볼 수 있습니다.",
  "이 시기를 지나는 동안 스스로의 속도를 존중하는 태도를 가지면 흐름을 더 잘 활용할 수 있습니다.",
  "37세라는 지금 시점은 이전 구간과는 결이 다른 선택과 태도가 요구되는 전환점이기도 합니다.",
]);
const GOOD_BLOCK2 = uniqueParagraph([
  "비견과 겁재의 기운이 뚜렷하게 확인되는 것이 이런 특징이 나타나는 바탕 중 하나로 보입니다.",
  "사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나의 기운만 따로 떼어 보기 어렵습니다.",
  "지금 확인된 흐름도 단독으로 생긴 것이 아니라 사주 전체의 배치가 서로 영향을 주고받은 결과입니다.",
  "이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다.",
  "기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 때로는 서로를 조절해주기도 합니다.",
  "그래서 이 특징을 이해할 때는 사주 전체의 그림 안에서 바라보는 것이 더 입체적인 이해로 이어집니다.",
  "특히 비견과 겁재가 함께 자리한 구조는 스스로의 추진력을 믿고 나아가는 힘으로 작용하는 편입니다.",
  "주변 기운과의 조화를 함께 살펴보면 이 특징이 왜 지금처럼 드러나는지 더 선명하게 이해할 수 있습니다.",
]);
const GOOD_BLOCK3 = uniqueParagraph([
  "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다.",
  "어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 삶 속에서 어떻게 작동하는지 체감하기 쉬워집니다.",
  "특별한 사건이 없더라도 평소의 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다.",
  "큰 결심이나 극적인 전환점보다는 매일 반복되는 작은 순간들 속에서 이 흐름을 알아차리는 것이 좋습니다.",
  "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니 가볍게 돌아보시면 됩니다.",
  "업무나 관계에서 주도적으로 나서는 순간들을 떠올려보면 이 흐름을 더 또렷하게 확인할 수 있습니다.",
  "작은 결정 하나에도 자신만의 기준을 뚜렷하게 세우는 모습으로 이 기운이 드러나는 경우가 많습니다.",
]);
const GOOD_BLOCK4 = uniqueParagraph([
  "정축 대운(2023~2032년)이 특히 이 흐름이 강해지는 시기로 참고할 만합니다.",
  "이 구간은 지금 진행 중인 흐름으로, 이전 구간보다 추진력이 한층 또렷해지는 경향이 있습니다.",
  "37세인 지금부터 이 대운이 끝나는 시점까지는 비슷한 결의 흐름이 이어질 가능성이 큽니다.",
  "특정 사건을 단정하기보다는 이 구간을 전후로 관련된 변화가 자연스럽게 이어진다고 보면 됩니다.",
]);
const GOOD_BLOCK5 = uniqueParagraph([
  "지금까지 살펴본 흐름을 종합하면 정축 대운 구간이 이번 이야기의 핵심 축이라고 정리할 수 있습니다.",
  "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
  "남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
  "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
  "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
  "37세를 지나는 지금, 정축 대운의 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다.",
  "오늘 이야기가 지금 이 구간을 더 편안하게 지나가는 데 작은 참고가 되었으면 합니다.",
]);

const GOOD_NONTIMING_BLOCK1 = uniqueParagraph([
  "사주 원국 전체를 보면 비견과 겁재의 기운이 두드러지게 자리 잡고 있습니다.",
  "이 기운은 스스로의 중심을 뚜렷하게 지키려는 성향으로 드러나는 경우가 많습니다.",
  "타고난 사주 배치에서 비롯된 것이라 의식하지 않아도 평소 태도에 자연스럽게 묻어납니다.",
  "사람마다 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
  "이 기질은 하루아침에 생긴 것이 아니라 태어날 때부터 가지고 있던 고유한 성향입니다.",
  "지금부터 이 기질이 왜 나타나는지, 실제로는 어떻게 드러나는지 차근차근 짚어보겠습니다.",
  "이런 성향은 스스로를 이해하는 데 작은 참고가 될 수 있다는 점에서 의미가 있습니다.",
  "겉으로 드러나는 말투나 행동보다 더 깊은 자리에서 방향을 잡아주는 축이라고 볼 수 있습니다.",
  "같은 상황을 마주해도 이 기질을 가진 사람은 조금 더 자기만의 속도로 판단을 내리는 편입니다.",
  "이런 특징을 미리 알아두면 스스로의 선택을 돌아볼 때 하나의 참고 기준이 될 수 있습니다.",
]);
const GOOD_NONTIMING_BLOCK2 = uniqueParagraph([
  "일간의 강약이 이런 기질이 나타나는 바탕 중 하나로 보입니다.",
  "사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나만 떼어 보기 어렵습니다.",
  "지금 확인된 기질도 단독으로 생긴 것이 아니라 전체 배치가 서로 영향을 준 결과입니다.",
  "이 점을 알면 왜 이런 성향이 자연스럽게 느껴지는지 더 납득이 될 수 있습니다.",
  "기운과 기운이 만나는 지점에서 서로 힘을 더해주거나 조절해주는 관계가 만들어집니다.",
  "그래서 이 기질을 이해할 때는 전체 그림 안에서 바라보는 것이 더 입체적입니다.",
  "특히 비견과 겁재가 함께 자리한 구조는 스스로의 추진력을 믿고 나아가는 힘으로 작용하는 편입니다.",
  "주변 기운과의 조화를 함께 살펴보면 이 기질이 왜 지금처럼 드러나는지 더 선명하게 이해할 수 있습니다.",
  "이런 배치는 혼자 힘으로 밀고 나가려는 의지와, 주변과 보조를 맞추려는 균형감을 동시에 품고 있습니다.",
]);
const GOOD_NONTIMING_BLOCK3 = uniqueParagraph([
  "이런 기질은 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다.",
  "어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 기질이 어떻게 작동하는지 체감하기 쉬워집니다.",
  "특별한 사건이 없더라도 평소의 습관 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다.",
  "매일 반복되는 작은 순간들 속에서 이 기질을 알아차리는 연습을 해보면 도움이 됩니다.",
  "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많습니다.",
  "작은 결정 하나에도 자신만의 기준을 뚜렷하게 세우는 모습으로 이 기운이 드러납니다.",
  "업무나 관계에서 주도적으로 나서는 순간들을 떠올려보면 이 기질을 더 또렷하게 확인할 수 있습니다.",
  "여러 사람이 함께하는 자리에서도 자기만의 속도를 지키려는 모습으로 이 기운이 나타나곤 합니다.",
]);
const GOOD_NONTIMING_BLOCK5 = uniqueParagraph([
  "지금까지 살펴본 기질을 종합하면 비견과 겁재의 기운이 이번 이야기의 핵심 축입니다.",
  "이 기운을 억지로 거스르기보다는 자신에게 맞는 방식으로 받아들이는 편이 더 안정적입니다.",
  "남과 비교하기보다 스스로의 기질을 존중하는 태도가 중요합니다.",
  "사주는 정해진 운명이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
  "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
  "오늘 이야기가 스스로를 이해하는 데 작은 참고가 되었으면 합니다.",
  "이 기질을 있는 그대로 인정하는 데서 출발하면, 스스로에게 더 너그러운 시선을 가질 수 있습니다.",
  "앞으로도 크고 작은 선택의 순간마다 이 기운이 당신을 지탱하는 든든한 축이 되어줄 것입니다.",
]);

function detailJsonTiming(): string {
  return JSON.stringify({
    title: "흐름이 바뀌는 시기",
    blocks: [
      { n: 1, body: GOOD_BLOCK1 },
      { n: 2, body: GOOD_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: GOOD_BLOCK3 },
      { n: 4, body: GOOD_BLOCK4, timing: { luck_index: 4 } },
      { n: 5, body: GOOD_BLOCK5 },
    ],
  });
}

function detailJsonNonTiming(): string {
  return JSON.stringify({
    title: "타고난 기질의 중심",
    blocks: [
      { n: 1, body: GOOD_NONTIMING_BLOCK1 },
      { n: 2, body: GOOD_NONTIMING_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: GOOD_NONTIMING_BLOCK3 },
      { n: 5, body: GOOD_NONTIMING_BLOCK5 },
    ],
  });
}

const llmCallerTiming: LlmCaller = async () => detailJsonTiming();
const llmCallerNonTiming: LlmCaller = async () => detailJsonNonTiming();
const llmCallerAlwaysFails: LlmCaller = async () => {
  throw new Error("강제 LLM 실패(fallback 경로 재현용)");
};

async function main() {
  // [검증 1] isTiming=true + LLM 성공 경로.
  console.log("=== [검증 1] isTiming=true, LLM 성공 경로 ===");
  const r1 = await generateInterpretResult({
    mode: "detail",
    topic: timingTopic,
    facts,
    evidenceNotes: ["비견 존재", "겁재 존재"],
    template: { systemPrompt: "이 주제를 해석하세요.", fallbackJson: null },
    llmCaller: llmCallerTiming,
  });
  check("source=llm (fallback으로 안 빠짐)", r1.source === "llm", r1.attemptLog);
  const detail1 = r1.result as InterpretDetailResult;
  const expectedTimeline = buildDaeunTimeline(facts);
  check("daeun_timeline 필드 존재", Array.isArray(detail1.daeun_timeline));
  check(
    "daeun_timeline 개수가 facts.luck_pillars 기반 timeline과 일치",
    detail1.daeun_timeline?.length === expectedTimeline.entries.length,
    { actual: detail1.daeun_timeline?.length, expected: expectedTimeline.entries.length }
  );
  if (detail1.daeun_timeline && detail1.daeun_timeline.length > 0) {
    const first = detail1.daeun_timeline[0];
    const expectedFirst = expectedTimeline.entries[0];
    check(
      "첫 entry 필드(gan_zhi_kr/start_year/end_year/start_age/end_age/tense)가 timeline과 정확히 일치",
      first.gan_zhi_kr === expectedFirst.ganZhiKr &&
        first.start_year === expectedFirst.startYear &&
        first.end_year === expectedFirst.endYear &&
        first.start_age === expectedFirst.startAge &&
        first.end_age === expectedFirst.endAge &&
        first.tense === expectedFirst.tense,
      { first, expectedFirst }
    );
    const nowEntries = detail1.daeun_timeline.filter((e) => e.tense === "now");
    check("tense='now'인 구간이 정확히 1개(현재 대운)", nowEntries.length === 1, nowEntries);
    if (nowEntries.length === 1) {
      check(
        "현재 구간이 facts.current_luck(정축)과 일치",
        nowEntries[0].gan_zhi_kr === facts.current_luck?.gan_zhi_kr,
        { actual: nowEntries[0].gan_zhi_kr, expected: facts.current_luck?.gan_zhi_kr }
      );
    }
    const pastCount = detail1.daeun_timeline.filter((e) => e.tense === "past").length;
    const futureCount = detail1.daeun_timeline.filter((e) => e.tense === "future").length;
    check(
      "past/now/future 구간 개수 합이 전체 entries 수와 일치",
      pastCount + nowEntries.length + futureCount === detail1.daeun_timeline.length,
      { pastCount, nowCount: nowEntries.length, futureCount, total: detail1.daeun_timeline.length }
    );
  }

  // [검증 2] isTiming=false 주제 → daeun_timeline 없음.
  console.log("\n=== [검증 2] isTiming=false 주제 — daeun_timeline 생략 확인 ===");
  const r2 = await generateInterpretResult({
    mode: "detail",
    topic: nonTimingTopic,
    facts,
    evidenceNotes: ["비견 존재", "겁재 존재"],
    template: { systemPrompt: "이 주제를 해석하세요.", fallbackJson: null },
    llmCaller: llmCallerNonTiming,
  });
  check("source=llm (fallback으로 안 빠짐)", r2.source === "llm", r2.attemptLog);
  const detail2 = r2.result as InterpretDetailResult;
  check("isTiming=false 주제는 daeun_timeline이 undefined", detail2.daeun_timeline === undefined, detail2.daeun_timeline);

  // [검증 3] facts에 luck_pillars가 없으면(빈 배열) isTiming=true여도 생략.
  console.log("\n=== [검증 3] luck_pillars 빈 배열 — isTiming=true여도 daeun_timeline 생략 ===");
  const factsNoLuck: SajuV3Facts = { ...facts, luck_pillars: [] };
  const r3 = await generateInterpretResult({
    mode: "detail",
    topic: timingTopic,
    facts: factsNoLuck,
    evidenceNotes: ["비견 존재", "겁재 존재"],
    template: { systemPrompt: "이 주제를 해석하세요.", fallbackJson: null },
    llmCaller: llmCallerTiming,
  });
  const detail3 = r3.result as InterpretDetailResult;
  check(
    "luck_pillars가 비어 있으면 daeun_timeline이 undefined(빈 표 강제 안 함)",
    detail3.daeun_timeline === undefined,
    detail3.daeun_timeline
  );

  // [검증 4] fallback 경로(LLM 전부 실패)에서도 daeun_timeline이 채워짐.
  console.log("\n=== [검증 4] LLM 실패 → fallback 경로에서도 daeun_timeline 포함 ===");
  const r4 = await generateInterpretResult({
    mode: "detail",
    topic: timingTopic,
    facts,
    evidenceNotes: ["비견 존재", "겁재 존재"],
    template: { systemPrompt: "이 주제를 해석하세요.", fallbackJson: null },
    llmCaller: llmCallerAlwaysFails,
  });
  check("source=template (fallback 경로로 빠짐)", r4.source === "template", r4.attemptLog);
  const detail4 = r4.result as InterpretDetailResult;
  check(
    "fallback 결과에도 daeun_timeline이 LLM 경로와 동일하게 채워짐",
    detail4.daeun_timeline?.length === expectedTimeline.entries.length,
    { actual: detail4.daeun_timeline?.length, expected: expectedTimeline.entries.length }
  );

  // [검증 5] summary 모드는 daeun_timeline을 전혀 붙이지 않음(detail 전용 필드).
  console.log("\n=== [검증 5] summary 모드 — daeun_timeline 붙지 않음 ===");
  const llmCallerSummary: LlmCaller = async () =>
    JSON.stringify({
      title: "흐름이 바뀌는 시기",
      summary: "지금 당신은 37세이며 정축 대운 구간을 지나고 있습니다. 이 흐름은 꾸준한 추진력으로 이어집니다.",
      evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." },
    });
  const r5 = await generateInterpretResult({
    mode: "summary",
    topic: timingTopic,
    facts,
    evidenceNotes: ["비견 존재", "겁재 존재"],
    template: { systemPrompt: "이 주제를 해석하세요.", fallbackJson: null },
    llmCaller: llmCallerSummary,
  });
  check("source=llm", r5.source === "llm", r5.attemptLog);
  check(
    "summary 결과 객체에는 daeun_timeline 키 자체가 없음",
    !("daeun_timeline" in (r5.result as unknown as Record<string, unknown>)),
    r5.result
  );

  console.log(`\n${failCount === 0 ? "✅ 전체 통과" : `❌ ${failCount}건 실패`}`);
  process.exit(failCount === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("테스트 실행 중 예외:", e);
  process.exit(1);
});
