// [정통사주 LLM 해석 공통 스펙 v2.0 — TK-8 "특수 주제 확장(궁합 multi_subject /
// 신살)" §5.3·§5.5·§8.5] 회귀 테스트.
//
// [조사에서 확인한 두 가지 사실 — 이 테스트가 고정하는 것]
//
// 1) 신살 게이트 배선 버그(이번에 수정): checkSinsalHallucination()과
//    GateProfile="sinsal" 자체는 TK-2(커밋 4f5df89)에서 이미 구현되고
//    dev-test-verification-gate.ts 단위 테스트도 통과했었다. 하지만
//    interpret-service.ts의 resolveGateProfile()이 topic.isTiming만 보고
//    "time_scoped"|"no_time" 둘 중 하나만 반환했기 때문에, 신살을 다루는
//    실제 topicId(RELATION_002: "귀인계 신살·용신 오행", LOVE_006: "배우자성
//    대운·도화")로 해석을 생성해도 sinsal 게이트가 단 한 번도 호출되지
//    않았다 — 즉 엔진 facts.sinsal에 없는 신살명을 LLM이 지어내도 차단되지
//    않는 사각지대였다. finding-detector.ts에 SINSAL_GATE_TOPIC_IDS를
//    추가하고 interpret-service.ts의 resolveGateProfile()이 이를 최우선
//    참조하도록 수정했다 — 이 테스트는 (a) 그 두 topicId에서 실제로
//    gateProfile="sinsal"이 적용되는지, (b) 엔진에 없는 신살명을 LLM이
//    지어내면 재시도 끝에 fallback으로 빠지는지를 generateInterpretResult()
//    전체 파이프라인 레벨에서 재현한다.
//
// 2) 궁합(multi_subject)은 "엔진 한계"가 아니라 "파이프라인 부재"다: saju-
//    engine-client.ts는 1인분 출생정보씩 받지만 두 사람 각각에 대해 호출하면
//    각자의 facts를 정상 산출할 수 있다(TK-5가 확인한 세운(연도별) facts
//    자체가 없는 경우와는 다름). 다만 topic-catalog-data.ts에 궁합 topicId가
//    없고 궁합 전용 프롬프트/라우트가 v2.0 파이프라인에 없으므로(기존
//    compatibility/* API는 TOPIC_POOL 고정 문구 기반 완전 별개 레거시),
//    "궁합 topic 자체"를 새로 만드는 것은 이번 TK-8 범위를 벗어난다.
//    대신 §8.5 "대상별(subject_id) 분리 검증" 요구사항이 실제로 작동하는
//    범용 프리미티브(runMultiSubjectGate)를 interpret-verification-gate.ts에
//    추가했다 — 이 테스트는 PDF §9 T10("궁합 — 두 사람 facts 각각 검증")
//    시나리오를 이 프리미티브로 직접 재현해 검증한다.
import { readFileSync } from "fs";
import { generateInterpretResult, type LlmCaller } from "../src/lib/saju-renewal/interpret-service";
import type { PromptTopicInfo } from "../src/lib/saju-renewal/interpret-prompt";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";
import { detectFindings, SINSAL_GATE_TOPIC_IDS } from "../src/lib/saju-renewal/finding-detector";
import {
  runMultiSubjectGate,
  hasBlockingMultiSubjectViolations,
  formatMultiSubjectViolationsForFeedback,
} from "../src/lib/saju-renewal/interpret-verification-gate";

let failCount = 0;
function check(label: string, condition: boolean, detail?: unknown) {
  console.log(`${condition ? "✅" : "❌"} ${label}${detail !== undefined ? ` — ${JSON.stringify(detail)}` : ""}`);
  if (!condition) failCount++;
}

const facts: SajuV3Facts = JSON.parse(readFileSync("/tmp/sample_facts.json", "utf-8"));
// sample_facts.json: sinsal=[天乙貴人(천을귀인), 華蓋(화개), 魁罡(괴강), 天德貴人(천덕귀인), 月德貴人(월덕귀인)]
// → "화개"는 facts.sinsal에 실제로 존재하므로 "허용된 신살"로, "역마"는 facts.sinsal에
//   없으므로 "환각 신살" 테스트에 쓴다.

function uniqueParagraph(seedSentences: string[]): string {
  return seedSentences.join(" ");
}

// ════════════════════════════════════════════════════════════════
// Part 1 — 신살 게이트 배선 수정 검증
// ════════════════════════════════════════════════════════════════
async function testSinsalGateWiring() {
  console.log("\n========== Part 1: 신살 게이트 배선 수정(RELATION_002/LOVE_006) ==========");

  check(
    "SINSAL_GATE_TOPIC_IDS에 RELATION_002 포함",
    SINSAL_GATE_TOPIC_IDS.has("RELATION_002")
  );
  check(
    "SINSAL_GATE_TOPIC_IDS에 LOVE_006 포함",
    SINSAL_GATE_TOPIC_IDS.has("LOVE_006")
  );
  check(
    "시기형 일반 주제(LIFE_001)는 신살 게이트 대상이 아님",
    !SINSAL_GATE_TOPIC_IDS.has("LIFE_001")
  );

  const relationTopic: PromptTopicInfo = {
    topicId: "RELATION_002",
    topicName: "귀인이 되는 사람의 특징",
    categoryGroup: "RELATION",
    isTiming: false, // 카탈로그 원문 그대로 — isTiming만 봤다면 "no_time"으로 샜을 것
  };

  // [GOOD] facts.sinsal에 실제로 있는 "화개"만 언급 — 위반 없이 1회 시도로 성공해야 함.
  const GOOD_BLOCK1 = uniqueParagraph([
    "당신 사주에는 화개라는 신살이 자리하고 있어 남다른 깊이와 통찰을 지니고 있습니다.",
    "이 기운은 혼자만의 시간 속에서 무언가를 깊이 파고드는 집중력으로 드러나는 경우가 많습니다.",
    "주변 사람들이 쉽게 지나치는 부분을 당신은 오래 들여다보는 편이라고 볼 수 있습니다.",
    "이런 성향은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 자연스럽게 이어집니다.",
    "사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다.",
    "지금부터 이 흐름이 실제로는 어떤 방식으로 드러나는지 차근차근 짚어보겠습니다.",
    "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
    "지금 확인된 이 흐름도 당신만의 고유한 특징 중 하나로 봐주시면 좋겠습니다.",
    "화개의 기운이 자리한 사람은 혼자 있는 시간을 불편해하지 않고 오히려 즐기는 경우가 많습니다.",
    "그래서 겉으로는 조용해 보여도 내면에서는 깊은 사유와 탐구가 이어지는 편입니다.",
  ]);
  const GOOD_BLOCK2 = uniqueParagraph([
    "비견과 겁재의 기운도 함께 확인되어 스스로의 기준을 뚜렷하게 세우는 바탕이 됩니다.",
    "주변 기운과의 조화를 함께 살펴보면 이 특징이 왜 지금처럼 드러나는지 더 선명해집니다.",
    "사주는 여러 기운이 서로 얽혀 균형을 이루는 구조라서 하나만 떼어 보기는 어렵습니다.",
    "이 점을 알고 나면 왜 이런 성향이 자연스럽게 느껴지는지 조금 더 납득이 될 수 있습니다.",
    "기운과 기운이 만나는 지점에서 서로 힘을 더해주기도 하고 서로를 조절해주기도 합니다.",
    "그래서 이 특징을 이해할 때는 사주 전체의 그림 안에서 바라보는 것이 입체적입니다.",
    "특히 비견과 겁재가 함께 자리한 구조는 스스로의 추진력을 믿고 나아가는 힘으로 작용하는 편입니다.",
    "화개와 비겁이 함께 있는 경우 혼자의 길을 묵묵히 걸어가는 힘이 더 또렷하게 드러납니다.",
  ]);
  const GOOD_BLOCK3 = uniqueParagraph([
    "이런 기운은 거창한 사건보다는 일상의 작은 선택과 태도에서 먼저 드러나는 경우가 많습니다.",
    "어떤 상황에서 더 편안함을 느끼는지 돌아보면 이 흐름이 어떻게 작동하는지 체감하기 쉬워집니다.",
    "특별한 사건이 없어도 평소 습관이나 선택 속에서 이 기운이 은근히 작용하고 있다고 보면 됩니다.",
    "주변 사람들과의 관계 속에서도 이런 성향이 은연중에 드러나는 경우가 많습니다.",
    "업무나 관계에서 주도적으로 나서는 순간들을 떠올려보면 이 흐름을 더 또렷하게 확인할 수 있습니다.",
    "작은 결정 하나에도 자신만의 기준을 뚜렷하게 세우는 모습으로 이 기운이 드러나는 경우가 많습니다.",
    "혼자 몰입할 수 있는 시간이 주어질 때 오히려 더 좋은 결과를 만들어내는 편이라고 볼 수 있습니다.",
  ]);
  const GOOD_BLOCK5 = uniqueParagraph([
    "지금까지 살펴본 흐름을 종합하면 화개라는 신살이 이번 이야기의 핵심 축이라 정리할 수 있습니다.",
    "이 기운을 억지로 거스르기보다는 자신에게 맞는 속도와 방식으로 받아들이는 편이 더 안정적입니다.",
    "남과 비교하기보다 스스로의 흐름을 존중하는 태도가 중요하며 오늘 이야기를 참고로 삼아보세요.",
    "사주는 정해진 운명을 통보하는 것이 아니라 당신이 가진 고유한 경향을 미리 비춰주는 거울입니다.",
    "이 거울을 참고해 스스로에게 맞는 선택을 차근차근 쌓아가다 보면 좋은 흐름으로 이어질 수 있습니다.",
    "오늘 이야기가 당신을 이해하는 데 작은 참고가 되었으면 합니다.",
    "화개의 깊이를 스스로 인정하고 받아들일 때 이 기운이 가장 긍정적인 방향으로 작용합니다.",
    "혼자의 시간을 부정적으로 여기지 말고 자신만의 자원으로 삼아보시길 권합니다.",
  ]);
  const detailJsonGood = () =>
    JSON.stringify({
      title: "귀인이 되는 사람의 특징",
      blocks: [
        { n: 1, body: GOOD_BLOCK1 },
        { n: 2, body: GOOD_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
        { n: 3, body: GOOD_BLOCK3 },
        { n: 5, body: GOOD_BLOCK5 },
      ],
    });

  let callCountGood = 0;
  const goodLlmCaller: LlmCaller = async () => {
    callCountGood++;
    return detailJsonGood();
  };
  const outcomeGood = await generateInterpretResult({
    mode: "detail",
    topic: relationTopic,
    facts,
    evidenceNotes: ["귀인계 신살(화개) 존재"],
    template: { systemPrompt: "이 주제는 귀인이 되는 사람의 특징을 다룹니다.", fallbackJson: null },
    llmCaller: goodLlmCaller,
  });
  check("[화개=실제 보유] 1회 시도로 성공(LLM 호출 1회)", callCountGood === 1, { callCountGood });
  check("[화개=실제 보유] 최종 source=llm", outcomeGood.source === "llm", { source: outcomeGood.source });

  // [BAD] facts.sinsal에 없는 "역마"를 지어냄 — sinsal 게이트가 작동 중이라면
  // SINSAL_HALLUCINATION으로 차단되어 재시도 끝에 fallback으로 빠져야 한다.
  // (배선 버그가 있었다면 gateProfile이 "no_time"이 되어 이 위반이 전혀
  // 검출되지 않고 1회 만에 "성공"으로 끝났을 것이다 — 그것이 바로 이 테스트가
  // 고정하려는 회귀다.)
  const BAD_BLOCK1 = uniqueParagraph([
    "당신 사주에는 역마라는 신살이 자리하고 있어 이동과 변화가 잦은 삶을 암시합니다.",
    "이 기운은 한곳에 머무르기보다 끊임없이 움직이려는 성향으로 드러나는 경우가 많습니다.",
    "주변 사람들이 안정을 추구할 때 당신은 새로운 자극을 찾아 나서는 편이라고 볼 수 있습니다.",
    "이런 성향은 타고난 사주 배치에서 비롯된 것으로 평소 태도와도 자연스럽게 이어집니다.",
    "사주 하나로 사람의 전부를 설명할 수는 없지만 이런 경향을 미리 알아두면 도움이 됩니다.",
    "지금부터 이 흐름이 실제로는 어떤 방식으로 드러나는지 차근차근 짚어보겠습니다.",
    "사람마다 타고난 기운의 배치가 다르기 때문에 같은 상황에서도 반응하는 방식이 다르게 나타납니다.",
    "지금 확인된 이 흐름도 당신만의 고유한 특징 중 하나로 봐주시면 좋겠습니다.",
    "역마의 기운이 자리한 사람은 낯선 환경에서도 빠르게 적응하는 편이라고 볼 수 있습니다.",
    "그래서 여행이나 이동이 많은 환경에서 오히려 활력을 얻는 경우가 많습니다.",
  ]);
  const detailJsonBad = () =>
    JSON.stringify({
      title: "귀인이 되는 사람의 특징",
      blocks: [
        { n: 1, body: BAD_BLOCK1 },
        { n: 2, body: GOOD_BLOCK2, evidence: { type: "grid", text: "비견과 겁재의 기운이 사주 원국에서 뚜렷하게 확인됩니다." } },
        { n: 3, body: GOOD_BLOCK3 },
        { n: 5, body: GOOD_BLOCK5 },
      ],
    });

  let callCountBad = 0;
  const badLlmCaller: LlmCaller = async () => {
    callCountBad++;
    return detailJsonBad();
  };
  const outcomeBad = await generateInterpretResult({
    mode: "detail",
    topic: relationTopic,
    facts,
    evidenceNotes: ["귀인계 신살(화개) 존재"],
    template: { systemPrompt: "이 주제는 귀인이 되는 사람의 특징을 다룹니다.", fallbackJson: null },
    llmCaller: badLlmCaller,
  });
  check("[역마=환각] MAX_LLM_ATTEMPTS(2회) 전부 시도됨", callCountBad === 2, { callCountBad });
  check("[역마=환각] 최종 source=template(fallback으로 빠짐)", outcomeBad.source === "template", {
    source: outcomeBad.source,
  });
  const sinsalViolationLogged = outcomeBad.attemptLog.some(
    (l) => l.includes("attempt") && l.includes("SINSAL_HALLUCINATION")
  );
  check(
    "[역마=환각] attemptLog에 SINSAL_HALLUCINATION 위반이 기록됨(sinsal 게이트가 실제로 작동)",
    sinsalViolationLogged,
    { attemptLog: outcomeBad.attemptLog }
  );
}

// ════════════════════════════════════════════════════════════════
// Part 2 — multi_subject(궁합) 분리 검증 프리미티브
// PDF §9 T10 "궁합 — 두 사람 facts 각각 검증" 시나리오를 그대로 재현.
// ════════════════════════════════════════════════════════════════
function testMultiSubjectGate() {
  console.log("\n========== Part 2: multi_subject(궁합) 분리 검증(PDF §9 T10 재현) ==========");

  // 사람A: sample_facts.json 그대로(현재 37세, 정축 대운, 용신 금속 계열)
  const factsA = facts;
  const findingsA = detectFindings(factsA);

  // 사람B: 다른 생년월일 가정 — 현재 29세, 다른 대운 시퀀스, 용신도 다르게(화/목).
  // [주의] factsA(sample_facts.json)의 실제 대운 간지 집합(경진·기묘·무인·정축·
  // 병자·을해·갑술·계유)과 완전히 겹치지 않는 간지만 골라야 한다 — 겹치면
  // checkGanzhiInEngine()이 "엔진 목록에 있는 간지"로 오인해 교차 오염 테스트가
  // 거짓으로 통과(위반 미검출)해버린다(1차 시도에서 실제로 "기묘"가 양쪽에
  // 우연히 겹쳐 이 실수가 드러났다). 60갑자 중 factsA에 전혀 없는 간지
  // (신사·임오·계미·갑신·을유)로 다시 구성한다.
  const factsB: SajuV3Facts = {
    pillars: { day: { gan: "丙", zhi: "午", kr: "병오" } },
    yongshin: { yong: "화", hee: "목", gi: "수", gu: undefined },
    current_age: 29,
    sinsal: ["桃花(도화)"],
    luck_pillars: [
      { start_age: 1, start_year: 1996, gan_zhi: "", gan_zhi_kr: "" },
      { start_age: 9, start_year: 2004, gan_zhi: "辛巳", gan_zhi_kr: "신사" },
      { start_age: 19, start_year: 2014, gan_zhi: "壬午", gan_zhi_kr: "임오" },
      { start_age: 29, start_year: 2024, gan_zhi: "癸未", gan_zhi_kr: "계미" },
      { start_age: 39, start_year: 2034, gan_zhi: "甲申", gan_zhi_kr: "갑신" },
    ],
  };
  const findingsB = detectFindings(factsB);

  const baseTopic = { topicId: "COMPAT_TEST", premiseRef: null, timeScoped: false, gateProfile: "multi_subject" as const };

  // [GOOD] 각자 자신의 대운/신살만 언급 — 교차 오염 없음, 위반 0건 기대.
  const textAGood = "당신은 지금 29세이며 계미 대운을 지나고 있고, 사주에는 도화라는 신살이 자리합니다.";
  // ↑ 의도적으로 "A의 텍스트"에 "B의 사실"(29세, 계미, 도화)을 섞어 교차 오염을
  //   재현한다 — multi_subject 분리 검증이 "A의 facts로 A의 텍스트만" 대조하므로
  //   이 텍스트를 A의 facts(실제 대운 목록에 '계미'가 전혀 없음)와 짝지으면
  //   GANZHI_NOT_IN_ENGINE(허위 간지)이 나야 정상이다 — baseTopic.timeScoped가
  //   false라서 ANCHOR_*(strictAnchor 전용) 검사는 비활성 상태이지만,
  //   GANZHI_NOT_IN_ENGINE은 strictAnchor와 무관하게 항상 동작한다(§8.1 4단계).
  const textBGood = "당신은 지금 29세이며 계미 대운을 지나고 있고, 사주에는 도화라는 신살이 자리합니다.";

  const crossContaminated = runMultiSubjectGate([
    { subjectId: "personA", facts: factsA, topic: baseTopic, findings: findingsA, text: textAGood },
    { subjectId: "personB", facts: factsB, topic: baseTopic, findings: findingsB, text: textBGood },
  ]);
  const personAViolations = crossContaminated.filter((v) => v.subjectId === "personA");
  const personBViolations = crossContaminated.filter((v) => v.subjectId === "personB");
  check(
    "[교차 오염 유도] personA 텍스트(B의 사실 포함)를 personA facts로 검증 → 위반 검출됨",
    personAViolations.length > 0,
    { personAViolations }
  );
  check(
    "[교차 오염 유도] personB 텍스트(자신의 사실)를 personB facts로 검증 → 위반 없음",
    personBViolations.length === 0,
    { personBViolations }
  );
  check(
    "위반에 subjectId가 정확히 태깅됨('personA'로 식별 가능)",
    personAViolations.every((v) => v.subjectId === "personA")
  );

  // [올바른 분리] 각자 자신에 대한 서술만 — 위반 0건 기대(§5.5 "대상별 분리 검증"의 정상 케이스).
  const textACorrect = "당신은 지금 37세이며 정축 대운을 지나고 있습니다.";
  const textBCorrect = "당신은 지금 29세이며 계미 대운을 지나고 있고, 사주에는 도화라는 신살이 자리합니다.";
  const properlySeparated = runMultiSubjectGate([
    { subjectId: "personA", facts: factsA, topic: baseTopic, findings: findingsA, text: textACorrect },
    { subjectId: "personB", facts: factsB, topic: baseTopic, findings: findingsB, text: textBCorrect },
  ]);
  check(
    "[올바른 분리] 각자 자신의 사실만 언급 → 위반 0건",
    properlySeparated.length === 0,
    { properlySeparated }
  );
  check(
    "hasBlockingMultiSubjectViolations() — 올바른 분리 시 false",
    !hasBlockingMultiSubjectViolations(properlySeparated)
  );
  check(
    "hasBlockingMultiSubjectViolations() — 교차 오염 시 true",
    hasBlockingMultiSubjectViolations(crossContaminated)
  );

  const feedback = formatMultiSubjectViolationsForFeedback(crossContaminated);
  check(
    "formatMultiSubjectViolationsForFeedback() — 피드백 문자열에 subjectId 포함",
    feedback.every((f) => f.startsWith("- [personA/") || f.startsWith("- [personB/")),
    { feedback }
  );

  // [신살 환각 + multi_subject 결합] personB의 facts.sinsal=[도화]인데 B의 텍스트가
  // "화개"(B에게 없는 신살)를 언급 → SINSAL_HALLUCINATION이 personB에만 태깅되어야 함.
  // runMultiSubjectGate()는 input.topic.gateProfile을 그대로 존중하므로(강제 덮어쓰기
  // 없음), 신살 검사를 받으려는 입력에는 gateProfile을 "sinsal"로 명시해야 한다
  // (§5.5 "게이트도 대상별 분리"는 대상별로 나눠 돈다는 뜻일 뿐, multi_subject
  // 프로파일 값 자체가 신살 검사를 자동으로 포함하지는 않음 — 신살 전용
  // 활성화 조건은 §8.5 그대로 gateProfile==='sinsal').
  const sinsalTopic = { ...baseTopic, gateProfile: "sinsal" as const };
  const textBWithFakeSinsal = "당신은 지금 29세이며 계미 대운을 지나고 있고, 사주에는 화개라는 신살이 있습니다.";
  const sinsalCombined = runMultiSubjectGate([
    { subjectId: "personA", facts: factsA, topic: sinsalTopic, findings: findingsA, text: textACorrect },
    { subjectId: "personB", facts: factsB, topic: sinsalTopic, findings: findingsB, text: textBWithFakeSinsal },
  ]);
  const sinsalViolation = sinsalCombined.find((v) => v.code === "SINSAL_HALLUCINATION");
  check(
    "[신살+multi_subject 결합] personB의 환각 신살(화개)이 SINSAL_HALLUCINATION으로 검출되고 personB에 태깅됨",
    !!sinsalViolation && sinsalViolation.subjectId === "personB",
    { sinsalViolation }
  );
}

async function main() {
  await testSinsalGateWiring();
  testMultiSubjectGate();

  console.log(`\n${failCount === 0 ? "✅ TK-8 전체 통과" : `❌ TK-8 실패 ${failCount}건`}`);
  if (failCount > 0) process.exit(1);
}

main();
