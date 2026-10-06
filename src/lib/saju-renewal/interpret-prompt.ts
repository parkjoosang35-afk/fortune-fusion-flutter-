// [정통사주 리뉴얼 v1.0 — STEP 4] Prompt 구성 — FACT + Topic + Evidence →
// TopicPromptTemplate(DB) 기반 systemPrompt/userPrompt 조립.
//
// [원칙 — 2025 진행 승인 지시 STEP4 §5·§13]
//   "LLM은 사주를 계산하면 안 됨" — 생년월일/출생시간을 던져서 재판단하게 하지 않는다.
//   LLM에게는 이미 계산된 SAJU FACTS + SELECTED TOPIC + TOPIC EVIDENCE만 전달한다.
//   "Prompt Template 29×2 사용" — 코드에 프롬프트를 대량 하드코딩하지 않고
//   TopicPromptTemplate(topicId+mode+systemPrompt+fallbackJson) DB를 조회해 쓴다.
//
// [이 파일의 역할 분담] TopicPromptTemplate.systemPrompt는 "이 주제를 어떤 관점으로
// 풀어야 하는가"(주제별 고유 지침)만 담당한다. "FACT 밖 이야기 금지", "내부코드
// 노출 금지", "AI 표현 금지", "출력 JSON 스키마" 같은 전역 규칙은 모든 주제가
// 동일하게 지켜야 하므로 COMMON_RULES로 이 파일에 고정하고, DB 템플릿 앞에 항상
// 덧붙인다(29종 각각의 DB 레코드에 전역 규칙을 중복 기재하지 않기 위함 — 운영 중
// 전역 규칙을 한 곳만 고치면 29종 전체에 즉시 반영되게 하는 설계).
import type { SajuV3Facts } from "./saju-facts-types";
import { renderTermDictionaryForPrompt } from "./interpret-term-dictionary";

export type InterpretMode = "summary" | "detail";

export interface PromptTopicInfo {
  topicId: string;
  topicName: string;
  categoryGroup: string;
  isTiming: boolean;
}

export interface PromptEvidenceInfo {
  factKeys: string[];
  notes: string[];
}

/** [FACT 최소화 — STEP4 §9·§18] LLM에게는 "이번 Topic 해석에 필요한 범위"만 전달한다.
 * facts 전체(JSON 전부)를 그대로 넘기면 LLM이 요청받지 않은 다른 영역(연애/건강 등)
 * 정보까지 참고해 Topic 집중도(§8)가 흐트러질 수 있다 — 공통 핵심 블록(일간/오행/
 * 용신/강약/대운 등)만 추려 전달한다. 내부 score/evaluator 같은 필드는 애초에
 * SajuV3Facts에 없으므로(엔진 응답 자체가 그런 필드를 안 줌) 별도 제거가 필요 없다.
 */
function buildFactDigest(facts: SajuV3Facts): Record<string, unknown> {
  return {
    day_master: facts.day_master
      ? { gan: facts.day_master.gan, kr: facts.day_master.kr, element: facts.day_master.element, yin_yang: facts.day_master.yin_yang }
      : undefined,
    day_master_strength: facts.day_master_strength,
    five_elements_weighted: facts.five_elements_weighted,
    yongshin: facts.yongshin
      ? { yong: facts.yongshin.yong, hee: facts.yongshin.hee, gi: facts.yongshin.gi, gu: facts.yongshin.gu }
      : undefined,
    pillars: facts.pillars,
    relations: facts.relations,
    current_luck: facts.current_luck,
    luck_pillars: facts.luck_pillars,
    sinsal: facts.sinsal,
  };
}

const SUMMARY_SCHEMA_INSTRUCTION = `
[출력 형식 — 이 JSON 스키마만 그대로 채워서 응답하세요. 다른 설명/마크다운/코드펜스 금지]
{
  "title": "이야기 제목(1차 문장, 사주 용어 원어 금지, [[ ]] 마크업 금지)",
  "summary": "핵심 이야기 2~3문장, 70~110자. 첫 문장에 사주 용어 원어를 쓰지 마세요. 마지막 문장은 그대로 인용되어 카드에 노출되니 완결된 문장으로 마침표로 끝내세요.",
  "evidence": {
    "type": "grid" | "elements" | "luck",
    "text": "근거 문장 1개, 25~45자. '자리(열)'로 지칭하세요."
  }
}`.trim();

// [STEP4 재수정 #2 — 분량 버그 근본 원인 수정] 기존 "90~180자×5블록=최대 900자" 지시는
// QA 허용 범위(1,500~2,500자)를 애초에 만족할 수 없는 구조적 결함이었다(CASE11에서
// 실측 639~839자로 드러남). 블록당 지시를 350~480자로 상향해 목표 총량(1,800~2,200자)을
// 구조적으로 달성 가능하게 한다. 동시에 "분량을 늘리기 위해 FACT 밖 내용을 만들거나
// 같은 문장을 반복하지 말라"는 지시를 명시한다(개발자 지시 §2 원문 반영).
//
// [버그 수정 — 2026-10-06 "진행" 지시 대응, 실측 기반 2차 수정]
// 서버 로그 전수 분석 결과, detail 요청의 LENGTH_OUT_OF_RANGE 실패(175건)가
// 거의 전부(실측: 16개 실패 토픽 전수) is_timing=false 주제(4블록: n=1,2,3,5)에서만
// 발생했다. 원인은 "블록당 350~480자" 지시가 5블록/4블록 모두에 동일하게
// 적용되어, 4블록 구조는 350×4=1,400자로 최소 기준(1,500자)에 구조적으로
// 못 미칠 위험이 있었기 때문이다(실측 LLM 응답도 1,300~1,490자 대에 집중).
// 이를 블록 개수에 따라 분기해 "4블록이면 블록당 더 길게" 쓰도록 명시한다
// (isTiming=false일 때 블록당 450~620자 → 목표 1,800~2,200자를 4블록으로도
// 구조적으로 달성 가능하게 함). 5블록(timing) 구조의 기존 350~480자 지시는
// 그대로 유지한다(해당 그룹은 이미 분량 기준을 안정적으로 만족하고 있었음).
function buildDetailSchemaInstruction(isTiming: boolean): string {
  const blockCount = isTiming ? 5 : 4;
  const perBlockRange = isTiming ? "350~480자" : "450~620자";
  const blockListExample = isTiming
    ? `  "blocks": [
    { "n": 1, "body": "[핵심 특징] 이 주제에서 가장 먼저 드러나는 특징이 무엇인지 설명합니다. 4~6문장, ${perBlockRange}." },
    { "n": 2, "body": "[왜] 그 특징이 사주 FACT상 왜 나타나는지, 어떤 기운의 배치/관계 때문인지 설명합니다. 4~6문장, ${perBlockRange}.", "evidence": { "type": "grid"|"elements"|"luck", "text": "근거 문장 25~45자" } },
    { "n": 3, "body": "[실제 생활] 이 특징이 일상 속 어떤 상황/선택/습관에서 구체적으로 드러나는지 설명합니다(1번·2번과 다른 구체적 장면 중심). 4~6문장, ${perBlockRange}." },
    { "n": 4, "body": "[시기] 전달받은 대운/시기 정보 범위 안에서 어느 시기를 전후로 흐름이 강해지는지 설명합니다. 4~6문장, ${perBlockRange}.", "timing": { "luck_index": 0 } },
    { "n": 5, "body": "[포인트] 이 사람이 이 흐름을 어떻게 받아들이고 활용하면 좋을지 조언합니다(1~4번과 다른, 행동/태도 중심의 결론). 4~6문장, ${perBlockRange}." }
  ]`
    : `  "blocks": [
    { "n": 1, "body": "[핵심 특징] 이 주제에서 가장 먼저 드러나는 특징이 무엇인지 설명합니다. 5~8문장, ${perBlockRange}." },
    { "n": 2, "body": "[왜] 그 특징이 사주 FACT상 왜 나타나는지, 어떤 기운의 배치/관계 때문인지 설명합니다. 5~8문장, ${perBlockRange}.", "evidence": { "type": "grid"|"elements"|"luck", "text": "근거 문장 25~45자" } },
    { "n": 3, "body": "[실제 생활] 이 특징이 일상 속 어떤 상황/선택/습관에서 구체적으로 드러나는지 설명합니다(1번·2번과 다른 구체적 장면 중심). 5~8문장, ${perBlockRange}." },
    { "n": 5, "body": "[포인트] 이 사람이 이 흐름을 어떻게 받아들이고 활용하면 좋을지 조언합니다(1~3번과 다른, 행동/태도 중심의 결론). 5~8문장, ${perBlockRange}." }
  ]`;

  return `
[분량 — 가장 중요하게 지켜야 할 규칙]
전체 결과(blocks의 body를 모두 합한 글자수)는 반드시 1,500~2,500자 범위여야 하며,
목표 분량은 1,800~2,200자입니다. 이번 주제는 총 ${blockCount}개 블록(n=${isTiming ? "1,2,3,4,5" : "1,2,3,5"})만
작성하세요(${isTiming ? "시기 블록(n=4)을 포함합니다" : "이 주제는 시기형이 아니므로 n=4(시기) 블록을 절대 포함하지 마세요"}).
각 블록은 "90~180자"처럼 짧게 끝내지 말고, 블록당 ${perBlockRange} 정도로 충분히 풀어서
설명하세요(${blockCount}블록 모두 이 분량으로 작성하면 목표 총량에 자연스럽게 도달합니다.
이 글자수 하한은 매우 중요합니다 — 미달 시 전체 응답이 자동으로 폐기되고 사용자에게
품질이 낮은 고정 템플릿 문구가 대신 노출되니, 반드시 각 블록을 하한 이상으로 충분히
풀어서 작성하세요).

분량을 채우기 위해 지켜야 할 것은 다음 두 가지뿐입니다:
1) 선택된 Topic과 전달받은 FACT/EVIDENCE를 더 구체적으로, 더 여러 각도에서
   설명하세요(예: 그 특징이 왜 나타나는지, 어떤 상황에서 드러나는지, 어떻게 받아들이면
   좋은지 등 — 같은 FACT를 다른 각도로 충분히 풀어 쓰면 자연스럽게 분량이 늘어납니다).
2) 절대 하지 말 것: (a) FACT에 없는 사실/사건/금액/직업/인간관계를 새로 만들어
   분량을 채우는 것, (b) 같은 문장이나 표현을 반복해 분량을 채우는 것, (c) 블록들이
   서로 거의 같은 내용을 말하는 것 — 각 블록은 아래 지정된 서로 다른 역할을
   수행해야 합니다.

[출력 형식 — 이 JSON 스키마만 그대로 채워서 응답하세요. 다른 설명/마크다운/코드펜스 금지]
{
  "title": "이야기 제목(summary 모드와 동일 제목)",
${blockListExample}
}`.trim();
}

/** [STEP4 §5·§9·§10·§11·§12 전역 규칙 — 29종 공통] 이 블록은 TopicPromptTemplate
 * 레코드마다 반복 기재하지 않고, 코드 레벨에서 항상 시스템 프롬프트 맨 앞에 붙인다. */
function buildCommonRules(mode: InterpretMode, isTiming: boolean): string {
  return `
당신은 "신통방통"이 이미 계산한 한 사람의 사주 원국(사주팔자)을 바탕으로, 그 사람에게
배정된 하나의 이야기 주제를 해석해 들려주는 역할입니다.

[가장 중요한 원칙 — 사주는 당신이 계산하지 않습니다]
아래 [SAJU FACTS]는 이미 계산 엔진이 산출을 끝낸 결과입니다. 생년월일이나 태어난 시간을
다시 보고 사주를 판단하거나 재계산하지 마세요. 당신의 역할은 오직 "이미 계산된 FACT를
근거로, 이미 선택된 하나의 TOPIC을 이야기로 풀어서 설명하는 것"뿐입니다.

[절대 금지 — FACT 밖의 이야기를 만들지 마세요]
- 특정 사건을 이미 겪었다고 단정하지 마세요(예: "이미 이혼하셨군요")
- 특정 직업을 가지고 있다고 단정하지 마세요
- 특정 금액을 벌었다/벌 것이다 작성하지 마세요
- 특정 가족관계를 임의로 만들지 마세요(배우자/자녀 유무 등)
- 특정 연애 경험을 임의로 만들지 마세요
- 근거 없는 날짜를 만들지 마세요
- 근거 없는 미래 사건을 확정하지 마세요
${
  isTiming
    ? "- 이 주제는 시기(timing) FACT가 있습니다 — 전달된 대운/시기 정보 범위 안에서만 시기를 언급하세요."
    : "- 이 주제는 시기(timing) FACT가 없습니다 — \"이 시기에 반드시 이런 일이 생깁니다\" 같은 시기 예측을 절대 만들지 마세요."
}

[주제 집중도 — 가장 중요]
이번에 해석할 주제 하나에 전체 내용을 집중하세요. 연애/가족/건강/직업/인간관계 등
다른 영역을 길게 설명하지 마세요. 다른 영역이 필요하더라도 이번 주제를 설명하는 데
꼭 필요한 범위 안에서만 짧게 언급하세요.

[절대 노출 금지 — 내부 정보]
다음과 같은 내부 코드/분류/숫자는 당신이 참고는 하되, 응답 텍스트에는 절대 쓰지 마세요:
topic_id(예: MONEY_002, PERSONALITY_001), 카테고리 코드, score, confidence, evaluator,
condition, DB id, "69종" 같은 내부 체계 명칭.

["AI" 표현 금지]
"AI가 분석했습니다", "인공지능이 판단했습니다" 같은 표현을 쓰지 마세요. 신통방통이
사주를 계산하고 그 안에서 이야기를 풀어주는 경험이어야 합니다.

[용어 규칙 — 매우 중요, 어기면 응답 전체가 자동 폐기됩니다]
아래 목록에 있는 10개 용어는 \`[[termKey|쉬운 표현]]\` 마크업으로 쓸 수 있습니다
(쉬운 표현이 1차로 노출되고, 탭하면 원어 설명이 보조로 뜹니다). 이 목록에 없는
termKey는 절대 만들지 마세요:
${renderTermDictionaryForPrompt()}

[아래 목록에 없는 사주 한자 용어 — 겁재/식상/비겁/편재/정재/관성/편관/정관/편인/정인/
상관/식신/지장간/신살/충/형/파/해 등 — 는 이 용어 사전에 등록되어 있지 않습니다.
이런 용어는 본문 어디에도(마크업 없이도, 괄호 안에도, 한자로도) 절대 쓰지 마세요.
대신 그 기운이 의미하는 내용을 완전히 풀어서 쉬운 우리말 문장으로 직접 설명하세요.
예: "겁재가 있으면" → "형제·동료처럼 가까운 사람과 나누어 쓰게 되는 기운이 있으면",
"식상이 강하면" → "자신을 표현하고 적극적으로 움직이는 기운이 강하면". 이 쉬운 설명
문장 자체가 분량을 채우는 좋은 재료이니 짧게 끝내지 말고 충분히 풀어서 쓰세요.]

[말투]
조용하고 따뜻한 존댓말(-요/-어요)을 사용하세요. 느낌표를 쓰지 마세요. 단정적 표현
("반드시", "절대", "틀림없이", "100%")을 쓰지 마세요.

${mode === "summary" ? SUMMARY_SCHEMA_INSTRUCTION : buildDetailSchemaInstruction(isTiming)}
`.trim();
}

export interface BuildInterpretPromptParams {
  mode: InterpretMode;
  topic: PromptTopicInfo;
  facts: SajuV3Facts;
  evidence: PromptEvidenceInfo;
  /** TopicPromptTemplate.systemPrompt — 이 주제 고유의 해석 관점/강조점(DB 조회 결과). */
  topicSpecificSystemPrompt: string;
}

export interface BuiltPrompt {
  systemPrompt: string;
  userPrompt: string;
}

export function buildInterpretPrompt(params: BuildInterpretPromptParams): BuiltPrompt {
  const { mode, topic, facts, evidence, topicSpecificSystemPrompt } = params;

  const systemPrompt = [
    buildCommonRules(mode, topic.isTiming),
    "",
    `[이번 주제 고유 지침]`,
    topicSpecificSystemPrompt.trim(),
  ].join("\n");

  const factDigest = buildFactDigest(facts);
  const userPrompt = [
    `[SELECTED TOPIC] ${topic.topicName}`,
    `[TOPIC EVIDENCE — 이 근거들이 실제로 통과한 이유]`,
    evidence.notes.length > 0 ? evidence.notes.map((n) => `- ${n}`).join("\n") : "- (별도 근거 설명 없음)",
    "",
    "[SAJU FACTS — 이미 계산 완료된 값, 재계산 금지]",
    JSON.stringify(factDigest),
    "",
    "위 FACTS와 EVIDENCE만 근거로, 위에서 지시한 JSON 스키마에 맞춰 이 사람의",
    `"${topic.topicName}" 이야기를 작성해주세요.`,
  ].join("\n");

  return { systemPrompt, userPrompt };
}
