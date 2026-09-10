// [신통방통 타로 65종 주제 연동 - AI Narrative Engine]
//
// Card Draw Engine이 확정한 카드에 대해서만 해석 텍스트를 생성하도록, AI에게
// 전달할 프롬프트를 구성한다. 원 지시서 핵심 요구사항:
//   AI에게 topic_id/topic_name/category/user_question/spread_id/card_count/
//   card_id/card_name/card_orientation/position_id/position_name/
//   position_purpose/card_basic_meaning/card_positive_meaning/
//   card_negative_meaning 모두 전달 — AI가 임의로 카드를 변경 못하게(카드는
//   이미 확정된 값으로만 프롬프트에 들어간다, AI는 이 값을 그대로 읽고 해석만
//   생성).
import { prisma } from "@/lib/db";
import type { DrawnCard } from "./card-draw-engine";

export interface PositionMeta {
  id: number;
  positionName: string;
  positionPurpose: string;
}

export interface PilotTopic {
  id: number;
  topicKey: string;
  categoryGroup: string;
  topicName: string;
  description: string | null;
  questionType: string;
  allowedSpreads: string[];
  yesNoEnabled: boolean;
  isChoiceAb: boolean;
  promptDomain: string;
  /** spreadType(one_card/three_card/five_card/yes_no) -> 포지션 순서 배열 */
  positionsBySpread: Record<string, PositionMeta[]>;
}

/**
 * `topicKey`(Flutter가 topic으로 보내는 값 = category.id)가 tarot_topics에
 * 등록되어 있으면 신규 엔진 경로에서 쓸 전체 메타데이터(포지션 포함)를
 * 조회해 반환한다. 없으면 null(레거시 경로로 처리하라는 신호).
 */
export async function getTopicWithPositions(topicKey: string): Promise<PilotTopic | null> {
  const topic = await prisma.tarotTopic.findUnique({
    where: { topicKey, status: "active" },
    include: {
      positions: {
        where: { status: "active", deletedAt: null },
        orderBy: { positionIndex: "asc" },
      },
    },
  });
  if (!topic) return null;

  const positionsBySpread: Record<string, PositionMeta[]> = {};
  for (const p of topic.positions) {
    if (!positionsBySpread[p.spreadType]) positionsBySpread[p.spreadType] = [];
    positionsBySpread[p.spreadType].push({
      id: p.id,
      positionName: p.positionName,
      positionPurpose: p.positionPurpose,
    });
  }

  let allowedSpreads: string[] = [];
  try {
    allowedSpreads = JSON.parse(topic.allowedSpreads) as string[];
  } catch {
    allowedSpreads = [];
  }

  return {
    id: topic.id,
    topicKey: topic.topicKey,
    categoryGroup: topic.categoryGroup,
    topicName: topic.topicName,
    description: topic.description,
    questionType: topic.questionType,
    allowedSpreads,
    yesNoEnabled: topic.yesNoEnabled,
    isChoiceAb: topic.isChoiceAb,
    promptDomain: topic.promptDomain,
    positionsBySpread,
  };
}

/**
 * AI Narrative Engine에 전달할 유저 프롬프트를 구성한다. 카드/포지션 정보는
 * 이미 확정된 값을 그대로 나열만 하며, AI가 이를 바꾸도록 요청하는 문구는
 * 절대 포함하지 않는다(오히려 "이미 확정된 카드"임을 명시해 임의 변경을 막는다).
 */
export function buildTopicSummaryPrompt(params: {
  topic: PilotTopic;
  spreadType: string;
  question: string;
  drawnCards: DrawnCard[];
  positionMetas: PositionMeta[];
  answer?: string;
  // [65종 타로 리딩엔진 §계획4 A/B 양자택일] choice_ab 스프레드 전용 —
  // 사용자가 입력한 두 선택지의 실제 텍스트(예: "이직한다" / "그대로 있는다").
  // AI 프롬프트에 그대로 노출해, "선택 A"/"선택 B"라는 추상 라벨이 아니라
  // 실제 선택지를 근거로 비교 조언을 생성하게 한다.
  optionA?: string;
  optionB?: string;
}): string {
  const { topic, spreadType, question, drawnCards, positionMetas, answer, optionA, optionB } =
    params;

  const spreadDesc =
    spreadType === "choice_ab"
      ? `A/B 양자택일 5장(${positionMetas.map((p) => p.positionName).join("-")})`
      : spreadType === "five_card"
        ? `5장(${positionMetas.map((p) => p.positionName).join("-")})`
        : spreadType === "three_card"
          ? `3장(${positionMetas.map((p) => p.positionName).join("-")})`
          : spreadType === "yes_no"
            ? "YES/NO 1장"
            : "1장";

  const cardsDesc = drawnCards
    .map((card, i) => {
      const pos = positionMetas[i];
      return [
        `[포지션 ${i + 1}] ${pos.positionName}`,
        `  - 포지션 해석목적: ${pos.positionPurpose}`,
        `  - 카드: ${card.nameKr}(${card.name})`,
        `  - 카드 방향: ${card.isReversed ? "역방향" : "정방향"}`,
        `  - 카드 기본의미(방향무관): ${card.basicMeaning}`,
        `  - 이번 방향의 해석: ${card.meaning}`,
      ].join("\n");
    })
    .join("\n\n");

  const lines = [
    `주제(topic_id=${topic.id}, topic_key=${topic.topicKey}): ${topic.topicName}`,
    `카테고리 그룹: ${topic.categoryGroup}`,
    `사용자 질문: ${question}`,
    `타로 스프레드: ${spreadDesc}`,
    "",
    "아래는 서버가 이미 확정하여 뽑은 카드들이다. 이 카드와 방향은 절대 변경되거나 다른 카드로 대체될 수 없다. 아래 정보를 그대로 근거로 삼아 해석 텍스트만 작성하라.",
    "",
    cardsDesc,
  ];

  if (spreadType === "choice_ab" && optionA && optionB) {
    lines.push(
      "",
      `선택지 A: ${optionA}`,
      `선택지 B: ${optionB}`,
      "위 5장 중 앞의 2장(선택 A 현재/결과 흐름)은 선택지 A를 골랐을 때의 카드이고, 다음 2장(선택 B 현재/결과 흐름)은 선택지 B를 골랐을 때의 카드이며, 마지막 1장(최종 조언)은 두 선택을 비교한 종합 조언 카드다.",
      "반드시 선택지 A와 선택지 B 각각의 흐름을 먼저 요약하고, 마지막에 두 선택지 중 어느 쪽이 더 나은 흐름인지 비교해 명확한 조언을 제시하라. 단, 사용자의 최종 결정을 대신 강요하지 말고 참고할 방향을 제안하는 톤으로 작성하라."
    );
  }

  if (answer) {
    lines.push(
      "",
      `카드가 가리키는 방향: ${answer}`,
      "답변은 반드시 YES 또는 NO 방향을 먼저 명확히 밝히고, 그 이유와 행동 힌트를 함께 제시하세요. YES/NO만 단답으로 끝내지 마세요."
    );
  }

  lines.push(
    "",
    "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서, 이 주제와 각 포지션의 해석목적에 맞춰 스프레드 전체에 대한 총평을 작성해주세요."
  );

  return lines.join("\n");
}
