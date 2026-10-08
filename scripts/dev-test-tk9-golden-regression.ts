// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-9 "전 주제 골든셋(회귀 방지)", §9]
//
// [TK-9 목표 — PDF §10.1 원문] "전 주제 골든셋(회귀 방지)" 요구사항 §9. 이 PDF의
// §9 수용기준표 자체가 "T1~T11" 개별 사례(대부분 이미 TK-2/TK-4/TK-6/TK-8에서
// 개별 스크립트로 재현됨)를 나열한 것이고, §10.2 "리스크"가 "주제별 facts 누락"·
// "프롬프트 톤 회귀"를 "골든 테스트로 고정"하라고 명시한다. 즉 TK-9는 "새 검증
// 규칙을 추가하는 작업"이 아니라, "이미 구현된 파이프라인(resolveGateProfile→
// findForTopic→buildInterpretPrompt→runVerificationGate)이 29종 전체 topicId에
// 대해 실제로 정상 동작하는지를 한 번에, 그리고 앞으로도 계속 고정해서 검사하는"
// 회귀 스위트다.
//
// [범위 — 무엇을 "골든"으로 고정하는가]
//   (A) 29종 전체 topicId 각각에 대해 resolveGateProfile()이 반환하는 프로파일이
//       기대값과 일치하는지(sinsal 2종 + time_scoped(isTiming) + no_time 나머지).
//       → 이 값이 조용히 바뀌면(예: 새 topicId 추가 시 매핑 실수) 즉시 실패한다.
//   (B) 29종 전체에 대해, "그 주제에 맞는 정상적인 골든 텍스트"를
//       generateInterpretResult()(llmCaller 모킹)로 흘려 1회 시도로 통과(source=
//       "llm")하는지 — PDF §9 T8 "주제 교차: 각 주제 해석, 게이트 통과 → 전 주제
//       일관성"을 글자 그대로 구현한다(29종 전부가 "교차 대상 주제").
//   (C) PDF §9 T9 "성격·기질 주제: 앵커 면제되어도 나이 언급 시 대조됨" — no_time
//       프로파일 주제(PERSONALITY_001)에 엔진 현재나이와 다른 나이를 억지로
//       넣으면 AGE_OUT_OF_RANGE는 아니지만, 범위 밖 나이 자체가 차단되는지는
//       기존 게이트 1단계(checkAgeOutOfRange)가 담당하므로 여기서는 "엔진과
//       다른 연도 언급 시 YEAR_OUT_OF_LIFE로 걸리는지"로 "언급 시 대조"를
//       재현한다(§8.5 no_time 정의 "앵커 검사 면제, 단 언급 시 나이/연도는 대조").
//   (D) PDF §9 T11 "동적 주제: finding 제목이 사주에서 생성되고 본문은 tense=과거
//       +현재 앵커" — tense=past인 premise(WEAKEST_DAEUN)를 과거시제로 올바르게
//       서술하면 통과, 미래시제로 서술하면 PREMISE_TENSE_MISMATCH로 차단되는지.
//
// [픽스처 설계 원칙] 각 topicId의 "정상 텍스트"는 QA(interpret-qa-check.ts: 분량
// 1500~2500자, 반복 금지, 내부코드 금지)와 게이트(interpret-verification-gate.ts:
// 현재 대운/나이 앵커링, 용신 환각 금지)를 동시에 통과해야 한다. 공통 뼈대
// 문단(사람마다 다르지 않은 일반 서술)에 topicId별로 다른 "고유 문장 1개"만
// 바꿔 끼워 29종이 서로 다른 문장을 갖게 한다(REPEATED_SENTENCE 회피 — 전부
// 똑같은 블록을 쓰면 동일 문장 반복으로 QA가 먼저 실패한다).
import { readFileSync } from "fs";
import {
  generateInterpretResult,
  resolveGateProfile,
  type LlmCaller,
} from "../src/lib/saju-renewal/interpret-service";
import type { PromptTopicInfo } from "../src/lib/saju-renewal/interpret-prompt";
import { TOPIC_CATALOG_SEED } from "../src/lib/saju-renewal/topic-catalog-data";
import { SINSAL_GATE_TOPIC_IDS, findForTopic } from "../src/lib/saju-renewal/finding-detector";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

const facts: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));
// sample_facts.json 고정값(다른 TK 스크립트와 동일 픽스처 — 재확인):
//   현재 대운: 정축(丁丑, 2023~2032), 현재나이(세는나이): 37세.
//   sinsal: 천을귀인·화개·괴강·천덕귀인·월덕귀인 (화개는 KNOWN_SINSAL_NAMES_KR에 포함).
//   yongshin: 용신=수, 희신=금 → "목(木)·수(水)" 식 환각 오행 문구는 쓰면 안 됨(수만 허용 + 금).

let failCount = 0;
function reportFail(label: string, detail: string) {
  failCount++;
  console.error(`❌ ${label}: ${detail}`);
}

// ────────────────────────────────────────────────────────────────
// (A) 29종 전체 gateProfile 골든 고정
// ────────────────────────────────────────────────────────────────
console.log("=== (A) 29종 topicId → resolveGateProfile() 골든 고정 ===");
const expectedProfile: Record<string, "time_scoped" | "no_time" | "sinsal"> = {};
for (const t of TOPIC_CATALOG_SEED) {
  expectedProfile[t.topicId] = SINSAL_GATE_TOPIC_IDS.has(t.topicId)
    ? "sinsal"
    : t.isTiming
      ? "time_scoped"
      : "no_time";
}
for (const t of TOPIC_CATALOG_SEED) {
  const info: PromptTopicInfo = { topicId: t.topicId, topicName: t.topicName, categoryGroup: t.categoryGroup, isTiming: t.isTiming };
  const actual = resolveGateProfile(info);
  const expected = expectedProfile[t.topicId];
  if (actual !== expected) {
    reportFail("(A) gateProfile 불일치", `${t.topicId}: 실제=${actual} 기대=${expected}`);
  }
}
const sinsalCount = Object.values(expectedProfile).filter((p) => p === "sinsal").length;
const timeScopedCount = Object.values(expectedProfile).filter((p) => p === "time_scoped").length;
const noTimeCount = Object.values(expectedProfile).filter((p) => p === "no_time").length;
console.log(`프로파일 분포 — sinsal:${sinsalCount} time_scoped:${timeScopedCount} no_time:${noTimeCount} (합계 ${sinsalCount + timeScopedCount + noTimeCount}/29)`);
if (sinsalCount !== 2) reportFail("(A) sinsal 개수", `기대 2(RELATION_002,LOVE_006), 실제 ${sinsalCount}`);
console.log(failCount === 0 ? "✅ (A) 통과\n" : "");

// ────────────────────────────────────────────────────────────────
// (B) 29종 전체 — 정상 텍스트 1회 통과 골든셋(§9 T8 "주제 교차 일관성")
// ────────────────────────────────────────────────────────────────
console.log("=== (B) 29종 전체 — 정상 텍스트 generateInterpretResult() 1회 통과(§9 T8) ===");

/** 공통 뼈대(현재 나이 37세·정축 대운 앵커링 포함) + topicId별 고유 문장 1개로
 * REPEATED_SENTENCE 회피. 글자수를 1,800~2,200자(목표 범위) 안에 맞춘다. */
function buildGoldenBlocks(uniqueSentence: string): string {
  const b1 = [
    "지금 당신은 37세이며 정축 대운 구간을 지나고 있습니다.",
    "이 구간은 2023년부터 2032년까지 이어지는 흐름으로 참고할 만합니다.",
    uniqueSentence,
    "사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다.",
    "지금부터 이 흐름이 왜 나타나는지 실제로는 어떤 방식으로 드러나는지 차근차근 짚어보겠습니다.",
    "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
    "지금 확인된 이 흐름도 당신만의 고유한 특징 중 하나로 봐주시면 좋겠습니다.",
    "정축 대운이 시작된 2023년 이후로 이런 경향이 조금씩 더 또렷해지고 있다고 볼 수 있습니다.",
    "이 시기를 지나는 동안 스스로의 속도를 존중하는 태도를 가지면 흐름을 더 잘 활용할 수 있습니다.",
    "37세라는 지금 시점은 이전 구간과는 결이 다른 선택과 태도가 요구되는 전환점이기도 합니다.",
  ].join(" ");
  const b2 = [
    "사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나의 기운만 따로 떼어 보기 어렵습니다.",
    "지금 확인된 흐름도 단독으로 생긴 것이 아니라 사주 전체의 배치가 서로 영향을 주고받은 결과입니다.",
    "이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다.",
    "기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 때로는 서로를 조절해주기도 합니다.",
    "그래서 이 특징을 이해할 때는 사주 전체의 그림 안에서 바라보는 것이 더 입체적인 이해로 이어집니다.",
    "주변 기운과의 조화를 함께 살펴보면 이 특징이 왜 지금처럼 드러나는지 더 선명하게 이해할 수 있습니다.",
    "이런 구조를 염두에 두고 보면 한 가지 기운의 강약만으로 섣불리 단정하기는 어렵다는 점도 함께 이해할 수 있습니다.",
  ].join(" ");
  const b3 = [
    "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다.",
    "어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 삶 속에서 어떻게 작동하는지 체감하기 쉬워집니다.",
    "특별한 사건이 없더라도 평소의 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다.",
    "큰 결심이나 극적인 전환점보다는 매일 반복되는 작은 순간들 속에서 이 흐름을 알아차리는 것이 좋습니다.",
    "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니 가볍게 돌아보시면 됩니다.",
    "업무나 관계에서 주도적으로 나서는 순간들을 떠올려보면 이 흐름을 더 또렷하게 확인할 수 있습니다.",
    "작은 선택이 쌓여 만들어내는 변화의 폭을 가볍게 넘겨보지 않는 태도가 결국 도움이 되는 경우가 많습니다.",
  ].join(" ");
  const b5 = [
    "지금까지 살펴본 흐름을 종합하면 정축 대운 구간이 이번 이야기의 핵심 축이라고 정리할 수 있습니다.",
    "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
    "남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
    "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
    "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
    "37세를 지나는 지금, 정축 대운의 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다.",
    "오늘 살펴본 이야기가 앞으로의 선택에도 작은 참고가 되었으면 하는 바람입니다.",
  ].join(" ");

  return JSON.stringify({
    title: "흐름을 이해하는 시간",
    blocks: [
      { n: 1, body: b1 },
      { n: 2, body: b2, evidence: { type: "grid", text: "사주 원국의 기운 배치가 이 흐름의 바탕을 이룹니다." } },
      { n: 3, body: b3 },
      { n: 5, body: b5 },
    ],
  });
}

/** topicId별 고유 문장 — 29종 서로 다른 내용(카테고리 성격 반영, 모두 안전한
 * 일반 서술이라 UNGROUNDED_FACT/금칙어/환각 오행·간지 트리거 없음). */
const UNIQUE_SENTENCE_BY_CATEGORY: Record<string, string> = {
  LIFE: "인생 전체의 큰 흐름 속에서 이 시기가 하나의 결을 만들어가고 있습니다.",
  MONEY: "재물과 관련된 선택에서도 이런 기운의 영향이 은근하게 느껴질 수 있습니다.",
  TALENT: "본인도 모르게 쌓아온 역량이 이 흐름 속에서 서서히 모습을 드러냅니다.",
  PERSONALITY: "타고난 기질의 결이 평소 말과 행동 속에 고스란히 녹아 있습니다.",
  RELATION: "주변 사람들과 맺는 관계의 방식에서도 이 기운이 꾸준히 작용합니다.",
  LOVE: "마음을 나누는 관계에서도 이런 흐름이 조용히 영향을 주는 편입니다.",
};

async function runGoldenForTopic(seed: (typeof TOPIC_CATALOG_SEED)[number]): Promise<void> {
  const topic: PromptTopicInfo = {
    topicId: seed.topicId,
    topicName: seed.topicName,
    categoryGroup: seed.categoryGroup,
    isTiming: seed.isTiming,
  };
  const uniqueSentence = UNIQUE_SENTENCE_BY_CATEGORY[seed.categoryGroup] ?? "이 주제만의 고유한 흐름이 확인됩니다.";
  let callCount = 0;
  const llmCaller: LlmCaller = async () => {
    callCount++;
    return buildGoldenBlocks(uniqueSentence);
  };
  const outcome = await generateInterpretResult({
    mode: "detail",
    topic,
    facts,
    evidenceNotes: ["사주 원국 기운 배치 근거"],
    template: { systemPrompt: `이 주제(${seed.topicName})는 ${seed.categoryGroup} 영역을 다룹니다.`, fallbackJson: null },
    llmCaller,
  });
  if (callCount !== 1 || outcome.source !== "llm") {
    reportFail(
      "(B) 정상 텍스트 1회 통과 실패",
      `${seed.topicId}(${seed.topicName}): callCount=${callCount} source=${outcome.source} attemptLog=${JSON.stringify(outcome.attemptLog)}`
    );
  }
}

async function runAllGolden(): Promise<void> {
  for (const seed of TOPIC_CATALOG_SEED) {
    await runGoldenForTopic(seed);
  }
  console.log(`29종 전체 실행 완료(${TOPIC_CATALOG_SEED.length}건).`);
}

// ────────────────────────────────────────────────────────────────
// (C) §9 T9 "성격·기질 주제: 앵커 면제되어도 나이/연도 언급 시 대조됨"
// ────────────────────────────────────────────────────────────────
async function runT9NoTimeStillChecked(): Promise<void> {
  console.log("\n=== (C) §9 T9 — no_time(PERSONALITY_001) 주제, 앵커 면제되어도 언급 시 나이/연도 대조 ===");
  const topic: PromptTopicInfo = { topicId: "PERSONALITY_001", topicName: "당신이 태어날 때부터 가지고 태어난 것", categoryGroup: "PERSONALITY", isTiming: false };
  const profile = resolveGateProfile(topic);
  if (profile !== "no_time") {
    reportFail("(C) 사전 조건", `PERSONALITY_001의 gateProfile이 no_time이 아님(실제=${profile})`);
  }

  // [BAD] 앵커링은 당연히 없어도 되지만(no_time), 생애 범위를 벗어난 연도를
  // 명시적으로 언급하면 YEAR_OUT_OF_LIFE로 차단되어야 한다("언급 시 대조").
  // sample_facts.json의 birth_solar=1990-05-15이므로 birthYear≈1990 — 생애
  // 범위(1990~2110)보다 명백히 이전인 "1950년"을 박아 넣는다. 단 YEAR_RE
  // 정규식(interpret-verification-gate.ts)이 "19\d{2}|20\d{2}"만 매치하므로
  // (1800년대는 매치 대상이 아님 — 애초에 YEAR_RE가 노리는 "현실적인 생애
  // 연도 주장"의 범위 밖), 1900년대 중 생애 이전 연도를 써야 실제로 검출된다.
  //
  // [디버깅으로 발견한 2차 함정 — QA가 게이트보다 먼저 실행되어 위반을 가림]
  // runSingleAttempt()(interpret-service.ts)는 runQaCheck()을 먼저 돌리고
  // QA가 실패하면 즉시 return해 runGateCheck()(검증 게이트, YEAR_OUT_OF_LIFE를
  // 포함)을 아예 실행하지 않는다. 처음 작성한 본문(n=1/2/3/5 합계 1,418자)이
  // DETAIL_MIN_LENGTH(1,500자)에 미달해 매 시도가 LENGTH_OUT_OF_RANGE로 먼저
  // 막혔고, 그 결과 YEAR_OUT_OF_LIFE 위반 자체가 attemptLog에 전혀 나타나지
  // 않는 거짓 실패가 발생했다(게이트 로직을 isolated로 직접 호출하면 정상
  // 검출됨을 먼저 확인해 "게이트는 멀쩡한데 왜 파이프라인에서는 안 잡히는가"로
  // 범위를 좁혔다). 각 블록 본문에 문장을 추가해 합계 1,687자로 늘려
  // LENGTH_OUT_OF_RANGE를 먼저 피하게 하면, 그 다음 검사인 YEAR_OUT_OF_LIFE가
  // 정상적으로 attemptLog에 `attempt1: QA_FAILED(- [YEAR_OUT_OF_LIFE] ...)`로
  // 기록됨을 확인했다(runQaCheck이 QA/게이트 위반 문자열을 모두 같은
  // QA_FAILED 로그 한 줄에 합쳐 쓰기 때문 — checkInterpretDetail 자체가 게이트
  // 위반 메시지 포맷(formatViolationsForFeedback)을 그대로 받아 failures에
  // 섞어 반환하는 것이 아니라, runSingleAttempt에서 qa.ok와 gate.ok를 같은
  // outcome.failures 배열로 합쳐 attemptLog에 "QA_FAILED"로 통일해 기록하는
  // 구조이므로, 라벨은 QA_FAILED지만 내용은 게이트 위반 메시지다).
  const badBlocks = () =>
    JSON.stringify({
      title: "타고난 기질의 결",
      blocks: [
        {
          n: 1,
          body: [
            "당신은 태어날 때부터 뚜렷한 기운의 결을 가지고 있습니다.",
            "1950년 무렵의 전통 방식으로 보더라도 이런 기질은 쉽게 바뀌지 않는 편입니다.",
            "이 기질은 평소 생활 전반에서 자연스럽게 드러나는 경우가 많습니다.",
            "타고난 성향을 이해하면 스스로를 더 편안하게 받아들이는 데 도움이 됩니다.",
            "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응 방식이 다릅니다.",
            "이 기질은 하루아침에 생긴 것이 아니라 태어날 때부터 가지고 있던 기운의 배치에서 비롯됩니다.",
            "앞으로도 이런 성향은 상황에 따라 다양한 방식으로 계속 모습을 드러낼 가능성이 큽니다.",
            "이 흐름을 이해해두면 스스로의 선택과 태도를 돌아보는 데 분명 도움이 될 수 있습니다.",
            "전반적으로 이 기운은 삶의 여러 장면에서 은근하지만 꾸준하게 영향을 미치는 편입니다.",
            "의식적으로 애쓰지 않아도 평소 생활 전반에 걸쳐 자연스럽게 묻어나는 편입니다.",
            "지금 이 시점에서 자신의 기질을 가볍게 돌아보는 것만으로도 충분히 의미 있는 시작이 될 수 있습니다.",
            "이런 특징을 인정하고 받아들이는 태도가 스스로를 이해하는 첫걸음이 되어줍니다.",
          ].join(" "),
        },
        {
          n: 2,
          body: [
            "비견과 겁재의 기운이 뚜렷하게 확인되는 것이 이런 특징이 나타나는 바탕 중 하나로 보입니다.",
            "사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나의 기운만 따로 떼어 보기 어렵습니다.",
            "지금 확인된 흐름도 단독으로 생긴 것이 아니라 사주 전체의 배치가 서로 영향을 주고받은 결과입니다.",
            "이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다.",
            "기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 때로는 서로를 조절해주기도 합니다.",
            "그래서 이 특징을 이해할 때는 사주 전체의 그림 안에서 바라보는 것이 더 입체적인 이해로 이어집니다.",
            "이런 구조를 염두에 두고 보면 한 가지 기운의 강약만으로 섣불리 단정하기는 어렵다는 점도 함께 이해할 수 있습니다.",
          ].join(" "),
          evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." },
        },
        {
          n: 3,
          body: [
            "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다.",
            "어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 삶 속에서 어떻게 작동하는지 체감하기 쉬워집니다.",
            "특별한 사건이 없더라도 평소의 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다.",
            "큰 결심이나 극적인 전환점보다는 매일 반복되는 작은 순간들 속에서 이 흐름을 알아차리는 것이 좋습니다.",
            "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니 가볍게 돌아보시면 됩니다.",
            "업무나 관계에서 주도적으로 나서는 순간들을 떠올려보면 이 흐름을 더 또렷하게 확인할 수 있습니다.",
            "작은 선택이 쌓여 만들어내는 변화의 폭을 가볍게 넘겨보지 않는 태도가 결국 도움이 되는 경우가 많습니다.",
          ].join(" "),
        },
        {
          n: 5,
          body: [
            "지금까지 살펴본 기질을 종합하면 타고난 결이 이번 이야기의 핵심 축이라고 정리할 수 있습니다.",
            "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
            "남과 비교하기보다 스스로의 성향을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
            "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다.",
            "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
            "꾸준히 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다.",
            "오늘 살펴본 이야기가 앞으로의 선택에도 작은 참고가 되었으면 하는 바람입니다.",
          ].join(" "),
        },
      ],
    });

  let callCountBad = 0;
  const badLlmCaller: LlmCaller = async () => {
    callCountBad++;
    return badBlocks();
  };
  const badOutcome = await generateInterpretResult({
    mode: "detail",
    topic,
    facts,
    evidenceNotes: ["비견 겁재 강한 신강 사주"],
    template: { systemPrompt: "이 주제는 타고난 기질을 다룹니다.", fallbackJson: null },
    llmCaller: badLlmCaller,
  });
  const yearViolationLogged = badOutcome.attemptLog.some((l) => l.includes("YEAR_OUT_OF_LIFE"));
  console.log(
    `1950년 언급 → YEAR_OUT_OF_LIFE로 attemptLog에 기록됨(언급 시 대조 확인)? ${yearViolationLogged} (LLM 호출 ${callCountBad}회, MAX_LLM_ATTEMPTS=2 소진 후 fallback 기대)`
  );
  console.log("최종 source:", badOutcome.source, "(기대: template — 결국 fallback으로 빠짐)");
  if (!yearViolationLogged) {
    reportFail("(C) T9", "no_time 프로파일에서 생애 범위 밖 연도 언급이 대조되지 않음(YEAR_OUT_OF_LIFE 미검출)");
  }
  if (badOutcome.source !== "template") {
    reportFail("(C) T9", `생애 범위 밖 연도 언급이 결국 차단되지 않음(source=${badOutcome.source})`);
  }
}

// ────────────────────────────────────────────────────────────────
// (D) §9 T11 "동적 주제: finding 제목이 사주에서 생성되고 본문은 tense=과거+현재 앵커"
// ────────────────────────────────────────────────────────────────
async function runT11PremiseTenseDynamic(): Promise<void> {
  console.log("\n=== (D) §9 T11 — 동적 premise(tense=past) 올바른 시제 서술 1회 통과, 틀린 시제는 PREMISE_TENSE_MISMATCH로 차단 ===");
  // sample_facts.json 기준 LIFE_002(시기형, TOPIC_TO_FINDING_CODE: STRONGEST_DAEUN)의
  // premise는 F_STRONGEST_병자(tense=future)다. T11이 요구하는 "tense=과거" 케이스를
  // 실제로 재현하려면 WEAKEST_DAEUN(F_WEAKEST_기묘, tense=past)을 premise로 직접
  // 구성한 topic으로 검증한다(findForTopic의 TOPIC_TO_FINDING_CODE 매핑에는
  // WEAKEST_DAEUN을 연결한 topicId가 없으므로, 이 테스트는 premise를 직접 주입해
  // "finding→topic" 동적 생성 자체가 아니라 §5.4/§5.6의 시제 대조 규칙을
  // 검증하는 것이다 — PREMISE_TENSE_MISMATCH는 TK-2에서 이미 구현된 로직을
  // TK-9가 골든으로 고정하는 것일 뿐, 새 규칙을 추가하지 않는다).
  const premise = findForTopic("LIFE_001", facts); // STRONGEST_DAEUN, tense=future (대조용 참고 로그만)
  console.log("참고: LIFE_001 실제 premise(STRONGEST_DAEUN) =", premise ? `${premise.span.ganzhi} tense=${premise.tense}` : "null");

  const weakestFinding = {
    finding_id: "F_WEAKEST_기묘",
    code: "WEAKEST_DAEUN" as const,
    subject: "self" as const,
    span: { ganzhi: "기묘", from: 2003, to: 2012, age_korean: [14, 23] as [number, number] },
    strength: 0.9,
    tense: "past" as const,
    evidence_refs: ["daeun[1]", "gisin"],
  };

  const pastGoodText =
    "지금 당신은 37세, 정축(丁丑) 대운(2023~2032) 구간에 있습니다. " +
    "이미 지난 14세부터 23세까지의 기묘(己卯) 대운은 상대적으로 조용히 다져가던 시기였습니다. " +
    "그 시절의 경험이 지금의 기반이 되어주고 있습니다.";
  const pastGoodBlocks = JSON.stringify({
    title: "지나온 흐름이 지금을 만든 시간",
    blocks: [
      { n: 1, body: pastGoodText + " 사주 전체에서 금 기운이 두드러지게 자리 잡아 안정적인 추진력을 보여줍니다. 이런 흐름은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 이어지는 경우가 많습니다. 사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다. 사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다. 정축 대운이 시작된 2023년 이후로 이런 경향이 조금씩 더 또렷해지고 있다고 볼 수 있습니다." },
      { n: 2, body: "비견과 겁재의 기운이 뚜렷하게 확인되는 것이 이런 특징이 나타나는 바탕 중 하나로 보입니다. 사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나의 기운만 따로 떼어 보기 어렵습니다. 지금 확인된 흐름도 단독으로 생긴 것이 아니라 사주 전체의 배치가 서로 영향을 주고받은 결과입니다. 이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다. 기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 때로는 서로를 조절해주기도 합니다.", evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다. 어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 삶 속에서 어떻게 작동하는지 체감하기 쉬워집니다. 특별한 사건이 없더라도 평소의 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다. 큰 결심이나 극적인 전환점보다는 매일 반복되는 작은 순간들 속에서 이 흐름을 알아차리는 것이 좋습니다. 주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니 가볍게 돌아보시면 됩니다." },
      { n: 5, body: "지금까지 살펴본 흐름을 종합하면 지나온 구간과 지금의 구간이 함께 이번 이야기의 핵심 축을 이룹니다. 이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다. 남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요. 사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다. 37세를 지나는 지금, 정축 대운의 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다." },
    ],
  });

  // [시제 오염 주의 — 1차 시도 디버깅으로 발견] 이 텍스트(와 title/n5 공통 문구)는
  // "지난/지나온/과거" 등 TENSE_PHRASES.past 트리거 단어를 단 하나도 포함해서는
  // 안 된다 — pastGoodBlocks와 title/n5 공통 블록을 그대로 재사용하면 title의
  // "지나온"이나 n5의 "지나온 구간" 문구가 past 허용 표현으로 오인되어
  // PREMISE_TENSE_MISMATCH가 가려지는 거짓 통과가 났었다(실제 재현된 버그).
  // 그래서 이 블록만 title/n5를 전용 문구로 새로 쓴다.
  const futureMismatchText =
    "지금 당신은 37세, 정축(丁丑) 대운(2023~2032) 구간에 있습니다. " +
    "앞으로 다가올 14세부터 23세까지의 기묘(己卯) 대운은 더욱 강해질 전망입니다.";
  const futureMismatchBlocks = JSON.stringify({
    title: "앞으로의 흐름이 기대되는 시간",
    blocks: [
      { n: 1, body: futureMismatchText + " 사주 전체에서 금 기운이 두드러지게 자리 잡아 안정적인 추진력을 보여줍니다. 이런 흐름은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 이어지는 경우가 많습니다. 사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다. 사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다. 정축 대운이 시작된 2023년 이후로 이런 경향이 조금씩 더 또렷해지고 있다고 볼 수 있습니다." },
      { n: 2, body: "비견과 겁재의 기운이 뚜렷하게 확인되는 것이 이런 특징이 나타나는 바탕 중 하나로 보입니다. 사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나의 기운만 따로 떼어 보기 어렵습니다. 지금 확인된 흐름도 단독으로 생긴 것이 아니라 사주 전체의 배치가 서로 영향을 주고받은 결과입니다. 이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다. 기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 때로는 서로를 조절해주기도 합니다.", evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
      { n: 3, body: "이런 기운은 보통 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다. 어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 삶 속에서 어떻게 작동하는지 체감하기 쉬워집니다. 특별한 사건이 없더라도 평소의 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다. 큰 결심이나 극적인 전환점보다는 매일 반복되는 작은 순간들 속에서 이 흐름을 알아차리는 것이 좋습니다. 주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많으니 가볍게 돌아보시면 됩니다." },
      { n: 5, body: "지금까지 살펴본 흐름을 종합하면 앞으로 이어질 구간과 지금의 구간이 함께 이번 이야기의 핵심 축을 이룹니다. 이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다. 남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요. 사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울에 가깝습니다. 37세를 지나는 지금, 정축 대운의 흐름을 염두에 두고 하루하루의 선택을 쌓아가 보시길 권합니다." },
    ],
  });

  // 직접 premiseRef를 주입할 수 있도록, 이 테스트만 topic.topicId를 임시로
  // "LIFE_002"(실제 카탈로그 topicId, isTiming=true)로 쓰되, findForTopic이
  // 반환하는 실제 premise 대신 수동으로 구성한 weakestFinding을 흘려보내려면
  // generateInterpretResult 내부 로직(premise=findForTopic(topic.topicId, facts))을
  // 그대로 타야 한다. 그런데 findForTopic(LIFE_002)는 STRONGEST_DAEUN을 반환하므로
  // (TOPIC_TO_FINDING_CODE 매핑), WEAKEST_DAEUN(tense=past)을 premise로 쓰는
  // "T11 과거형" 경로는 현재 매핑에 존재하지 않는다 — 즉 findForTopic 경로가
  // 아니라 interpret-verification-gate.ts의 runVerificationGate()를 직접 호출해
  // PREMISE_TENSE_MISMATCH 규칙 자체(§5.4/§5.6)를 골든으로 고정한다. 이것이
  // "generateInterpretResult 통합 테스트"가 아니라 "게이트 단위 골든"인 이유를
  // 명시적으로 남긴다(TK-2 dev-test-verification-gate.ts와 같은 레이어, 이번엔
  // "확정된 29종 픽스처 + PDF T11 조건"으로 한 번 더 고정하는 것).
  const { runVerificationGate } = await import("../src/lib/saju-renewal/interpret-verification-gate");
  const topicInput = { topicId: "LIFE_002", premiseRef: weakestFinding.finding_id, timeScoped: true, gateProfile: "time_scoped" as const };

  const v1 = runVerificationGate({ facts, topic: topicInput, findings: [weakestFinding], text: JSON.parse(pastGoodBlocks).blocks.map((b: { body: string }) => b.body).join(" ") });
  console.log("과거형(tense=past)을 '이미 지난'으로 올바르게 서술 → 위반 0건 기대:", v1);
  if (v1.length !== 0) reportFail("(D) T11 과거형 올바른 서술", `위반이 발생함: ${JSON.stringify(v1)}`);

  const v2 = runVerificationGate({ facts, topic: topicInput, findings: [weakestFinding], text: JSON.parse(futureMismatchBlocks).blocks.map((b: { body: string }) => b.body).join(" ") });
  const hasTenseMismatch = v2.some((v) => v.code === "PREMISE_TENSE_MISMATCH");
  console.log("과거형(tense=past)을 '앞으로'로 잘못 서술 → PREMISE_TENSE_MISMATCH 기대:", v2.filter((v) => v.code === "PREMISE_TENSE_MISMATCH"));
  if (!hasTenseMismatch) reportFail("(D) T11 시제 불일치 미검출", `PREMISE_TENSE_MISMATCH가 검출되지 않음: ${JSON.stringify(v2)}`);

  // [동적 제목 측면] "finding 제목이 사주에서 생성"되는 부분은 §5.3/§5의 "finding→
  // topic" 설계 의도이며, 실제 LLM 제목 문구 생성은 이 서비스 계층 책임이 아니라
  // 프롬프트(interpret-prompt.ts)가 premise.code/span을 systemPrompt에 주입해
  // LLM이 제목을 짓게 하는 구조다(dev-test-prompt-anchoring.ts가 이미 "[FINDING]"
  // 섹션 주입을 검증함). 여기서는 생략된 검증을 중복하지 않고, 이 테스트의 책임
  // 범위(시제 대조)만 명확히 마무리한다.
}

async function main() {
  await runAllGolden();
  await runT9NoTimeStillChecked();
  await runT11PremiseTenseDynamic();

  if (failCount === 0) {
    console.log("\n✅ TK-9 전 주제 골든셋(회귀 방지) 전체 통과 — 29종 gateProfile 고정 + 29종 정상 텍스트 1회 통과(T8) + no_time 언급 시 대조(T9) + premise 시제 대조(T11)");
  } else {
    console.error(`\n❌ TK-9 골든셋 ${failCount}건 실패`);
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("스크립트 실행 중 오류:", e);
  process.exitCode = 1;
});
