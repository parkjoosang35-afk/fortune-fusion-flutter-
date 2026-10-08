// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-2 연동] generateInterpretResult()에 연결된
// 검증 게이트가 실제로 재시도를 트리거하는지 DB/Next.js 없이 llmCaller를 모킹해
// 검증한다. dev-test-interpret-api.ts(실제 HTTP+DB 필요)와 달리 이 스크립트는
// 순수 함수 레벨에서 게이트 연동 자체만 독립적으로 재현한다.
//
// [픽스처 작성 시 주의 — 1차 시도에서 발견된 실수 기록]
// 처음에는 "정상 텍스트" 블록 본문을 `.repeat(10)`으로 만들었는데, 이는
// interpret-qa-check.ts의 checkRepetition()이 "동일 문장 2회 이상 등장"을
// 그 자체로 QA 실패(REPEATED_SENTENCE)로 처리하기 때문에 게이트까지 가지도
// 못하고 QA 단계에서 이미 탈락했다. 또한 evidence.text에 쓴 "테스트용"이라는
// 단어가 INTERNAL_LEAK_PATTERNS(/테스트용/)에 걸려 추가로 QA를 실패시켰다.
// 이번 버전은 블록마다 서로 다른 문장을 이어 붙여 분량(1,500~2,500자)을
// 채우면서도 반복/금칙어 없이 QA를 통과하도록 다시 작성했다 — 게이트 자체의
// 동작만 독립적으로 검증하기 위함이다(QA는 이미 별도로 검증됨).
import { readFileSync } from "fs";
import { generateInterpretResult, type LlmCaller } from "../src/lib/saju-renewal/interpret-service";
import type { PromptTopicInfo } from "../src/lib/saju-renewal/interpret-prompt";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const facts: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));
// sample_facts.json 현재 대운: 정축(2023-2032), 현재나이 37세(이전 스모크테스트로 확인됨).

const timingTopic: PromptTopicInfo = { topicId: "LIFE_001", topicName: "인생의 흐름", categoryGroup: "LIFE", isTiming: true };

// [반복문장 QA 회피용] 블록마다, 그리고 블록 내부에서도 서로 다른 문장을 쓴다.
// 각 문장은 8자 이상이라 checkRepetition 대상이지만, 모두 1회만 등장하므로 안전하다.
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
const GOOD_BLOCK5 = uniqueParagraph([
  "지금까지 살펴본 흐름을 종합하면 정축 대운 구간이 이번 이야기의 핵심 축이라고 정리할 수 있습니다.",
  "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
  "남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
  "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
  "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
  "37세를 지나는 지금, 정축 대운의 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다.",
  "오늘 이야기가 지금 이 구간을 더 편안하게 지나가는 데 작은 참고가 되었으면 합니다.",
]);

const detailJsonGood = (): string =>
  JSON.stringify({
    title: "흐름이 바뀌는 시기",
    blocks: [
      { n: 1, body: GOOD_BLOCK1 },
      { n: 2, body: GOOD_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: GOOD_BLOCK3 },
      { n: 5, body: GOOD_BLOCK5 },
    ],
  });

// [bad] good과 동일한 분량/품질이지만, 현재 나이(37세)·현재 대운(정축) 언급만 의도적으로 제거함
// → ANCHOR_AGE_MISSING / ANCHOR_DAEUN_MISSING 두 가지 차단 위반을 유발해야 한다.
const BAD_BLOCK1 = uniqueParagraph([
  "당신은 사주 전체에서 금 기운이 두드러지게 자리 잡은 사람입니다.",
  "이런 흐름은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 이어지는 경우가 많습니다.",
  "사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다.",
  "지금부터 이 흐름이 왜 나타나는지 실제로는 어떤 방식으로 드러나는지 차근차근 짚어보겠습니다.",
  "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
  "지금 확인된 이 흐름도 당신만의 고유한 특징 중 하나로 봐주시면 좋겠습니다.",
  "의식적으로 애쓰지 않아도 평소 생활 전반에 걸쳐 자연스럽게 묻어나는 편입니다.",
  "이 특징은 하루아침에 생긴 것이 아니라 태어날 때부터 가지고 있던 기운의 배치에서 비롯됩니다.",
  "앞으로도 이런 성향은 상황에 따라 다양한 방식으로 계속 모습을 드러낼 가능성이 큽니다.",
  "이 흐름을 이해해두면 스스로의 선택과 태도를 돌아보는 데 분명 도움이 될 수 있습니다.",
  "전반적으로 이 기운은 삶의 여러 장면에서 은근하지만 꾸준하게 영향을 미치는 편입니다.",
]);

// [bad] n=5 블록도 "정축"/"37세" 언급이 없는 전용 버전을 따로 둔다 — GOOD_BLOCK5를
// 재사용하면 거기에 앵커 언급이 섞여 있어 bad 픽스처의 의도(앵커링 완전 누락)가
// 깨지기 때문이다(1차 시도에서 실제로 이 실수로 테스트가 거짓 실패했음).
const BAD_BLOCK5 = uniqueParagraph([
  "지금까지 살펴본 흐름을 종합하면 이번 이야기의 핵심 축을 정리해볼 수 있습니다.",
  "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
  "남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
  "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
  "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
  "꾸준히 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다.",
  "오늘 이야기가 지금 이 구간을 더 편안하게 지나가는 데 작은 참고가 되었으면 합니다.",
]);

const detailJsonBad = (): string =>
  JSON.stringify({
    title: "흐름이 바뀌는 시기",
    blocks: [
      { n: 1, body: BAD_BLOCK1 },
      { n: 2, body: GOOD_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: GOOD_BLOCK3 },
      { n: 5, body: BAD_BLOCK5 },
    ],
  });

function visibleLen(s: string): number {
  return s.length;
}

async function main() {
  console.log(
    "사전 점검 — good/bad 블록 합산 글자수(1500~2500자 범위 확인):",
    "good=",
    [GOOD_BLOCK1, GOOD_BLOCK2, GOOD_BLOCK3, GOOD_BLOCK5].reduce((s, b) => s + visibleLen(b), 0),
    "bad=",
    [BAD_BLOCK1, GOOD_BLOCK2, GOOD_BLOCK3, BAD_BLOCK5].reduce((s, b) => s + visibleLen(b), 0)
  );

  console.log("\n=== 1) 앵커링(나이/대운) 언급이 빠진 텍스트만 반환하는 llmCaller — 게이트가 계속 재시도시키고, 결국 fallback으로 빠지는지 확인 ===");
  let callCount1 = 0;
  const badLlmCaller: LlmCaller = async () => {
    callCount1++;
    return detailJsonBad();
  };
  const outcome1 = await generateInterpretResult({
    mode: "detail",
    topic: timingTopic,
    facts,
    evidenceNotes: ["비견 겁재 강한 신강 사주"],
    template: { systemPrompt: "이 주제는 인생 전반의 흐름을 다룹니다.", fallbackJson: null },
    llmCaller: badLlmCaller,
  });
  console.log("LLM 호출 횟수:", callCount1, "(기대: 2 — MAX_LLM_ATTEMPTS)");
  console.log("최종 source:", outcome1.source, "(기대: template — LLM이 끝까지 게이트를 통과 못해 fallback으로 빠짐)");
  console.log("attemptLog:", JSON.stringify(outcome1.attemptLog, null, 2));
  const gateFailedLogged = outcome1.attemptLog.some(
    (l) => l.includes("ANCHOR_DAEUN_MISSING") && l.includes("attempt")
  ) && outcome1.attemptLog.some((l) => l.includes("ANCHOR_AGE_MISSING") && l.includes("attempt"));
  console.log("attempt 단계 attemptLog에 ANCHOR_* 위반이 기록됨(QA가 아니라 게이트에서 막힘)?", gateFailedLogged);

  console.log("\n=== 2) 앵커링(나이/대운) 언급이 포함된 정상 텍스트를 반환하는 llmCaller — 1회 시도로 성공해야 함 ===");
  let callCount2 = 0;
  const goodLlmCaller: LlmCaller = async () => {
    callCount2++;
    return detailJsonGood();
  };
  const outcome2 = await generateInterpretResult({
    mode: "detail",
    topic: timingTopic,
    facts,
    evidenceNotes: ["비견 겁재 강한 신강 사주"],
    template: { systemPrompt: "이 주제는 인생 전반의 흐름을 다룹니다.", fallbackJson: null },
    llmCaller: goodLlmCaller,
  });
  console.log("LLM 호출 횟수:", callCount2, "(기대: 1)");
  console.log("최종 source:", outcome2.source, "(기대: llm)");
  console.log("attemptLog:", JSON.stringify(outcome2.attemptLog, null, 2));

  if (callCount1 !== 2 || outcome1.source !== "template" || !gateFailedLogged) {
    console.error("\n❌ 게이트가 앵커링 누락 응답을 계속 재시도/fallback으로 빠뜨리지 못함 — interpret-service.ts 연동 점검 필요.");
    process.exit(1);
  }
  if (callCount2 !== 1 || outcome2.source !== "llm") {
    console.error("\n❌ 게이트/QA가 정상 응답까지 불필요하게 거부함 — 과검출 회귀 위험.");
    process.exit(1);
  }

  console.log("\n✅ TK-2 연동(interpret-service.ts ↔ interpret-verification-gate.ts) 검증 통과");
}

main().catch((e) => {
  console.error("스크립트 실행 중 오류:", e);
  process.exit(1);
});
