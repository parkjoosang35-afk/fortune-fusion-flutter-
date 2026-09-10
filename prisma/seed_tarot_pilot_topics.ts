// [신통방통 타로 65종 주제 연동 - 1차 파일럿 5개 주제 시딩]
// 대표님 승인 계획 4단계: "5개 파일럿(썸의 흐름/상대의 속마음/재회 가능성/
// 이직운/금전운) 구현" 중 DB 데이터(tarot_topics/tarot_positions) 부분.
//
// topic_key는 Flutter TarotCategoryMeta.id와 1:1 대응한다(스키마 설계 결정).
//   love_flow_of_crush   = 썸의 흐름
//   love_inner_truth     = 상대의 속마음
//   love_reunion_chance  = 재회 가능성
//   career_job_change    = 이직운
//   wealth_fortune       = 재물운/금전운
//
// 각 주제는 one_card(1장) / three_card(3장) / five_card(5장) 스프레드를
// 모두 지원하며, 포지션별 position_purpose는 AI Narrative Engine 프롬프트에
// 그대로 전달되어 "포지션별 해석목적"을 명확히 고정한다(원 지시서 핵심 요구).
//
// yes_no_enabled: 재회 가능성/이직운 2개가 true(대표님 마스터 프롬프트 §17의
// YES/NO 12개 확정 목록에 포함됨 — "재회할 수 있을까?", "이직할 수 있을까?"
// 형태의 단답형 질문에 적합) — 나머지 3개(썸의 흐름/상대의 속마음/재물운)는
// §17 목록에 없고 열린 질문형 리딩이 본질에 더 맞아 false로 설계.
// is_choice_ab: 5개 파일럿 모두 false(43번 선택의 방향은 별도 개발 대상, 이번
// 범위 아님).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

interface PositionSeed {
  // [career_job_change YES/NO 추가 반영] 기존 타입 정의에 "yes_no"가 빠져있던
  // 잠재 버그(재회 가능성만 yes_no 스프레드를 가져서 그동안 드러나지 않았음)를
  // 이직운 yes_no 스프레드 추가 과정에서 발견해 함께 수정한다.
  spreadType: "one_card" | "three_card" | "five_card" | "yes_no";
  positions: { name: string; purpose: string }[];
}

interface TopicSeed {
  topicKey: string;
  categoryGroup: string;
  topicName: string;
  description: string;
  questionType: string;
  allowedSpreads: string[];
  yesNoEnabled: boolean;
  isChoiceAb: boolean;
  promptDomain: string;
  spreads: PositionSeed[];
}

const TOPICS: TopicSeed[] = [
  {
    topicKey: "love_flow_of_crush",
    categoryGroup: "love",
    topicName: "썸의 흐름",
    description: "흔들리는 마음의 방향, 지금 두 사람 사이의 기류와 앞으로의 흐름을 읽는 주제",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "현재 흐름", purpose: "지금 두 사람 사이의 전반적인 기류와 분위기를 종합적으로 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금 분위기", purpose: "현재 두 사람 사이에 흐르는 감정적 분위기와 온도를 보여준다" },
          { name: "그 사람 마음", purpose: "상대방이 지금 이 관계에 대해 느끼고 있는 감정과 태도를 보여준다" },
          { name: "앞으로 흐름", purpose: "이 썸이 앞으로 어떤 방향으로 흘러갈지 그 흐름과 가능성을 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "나의 마음", purpose: "질문자 스스로 이 관계에 대해 느끼는 진짜 감정을 보여준다" },
          { name: "상대의 마음", purpose: "상대방이 이 관계에 대해 느끼고 있는 감정과 태도를 보여준다" },
          { name: "현재 관계 기류", purpose: "지금 두 사람 사이에 형성된 관계의 전반적 기류를 보여준다" },
          { name: "장애물/변수", purpose: "이 썸의 진전을 막거나 흔드는 장애물, 외부 변수를 보여준다" },
          { name: "앞으로의 흐름", purpose: "이 관계가 앞으로 나아갈 방향과 최종적인 흐름을 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_inner_truth",
    categoryGroup: "love",
    topicName: "상대의 속마음",
    description: "말하지 않은 진심, 상대방이 겉으로 드러내지 않는 속마음을 읽는 주제",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "속마음", purpose: "상대방이 지금 숨기고 있는 진짜 마음의 핵심을 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "겉으로 보이는 모습", purpose: "상대방이 겉으로 드러내는 태도와 표현을 보여준다" },
          { name: "숨겨진 진심", purpose: "겉모습 뒤에 감춰진 상대방의 진짜 감정을 보여준다" },
          { name: "나에 대한 실제 감정", purpose: "상대방이 질문자에 대해 실제로 품고 있는 감정의 방향을 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "겉모습", purpose: "상대방이 평소 겉으로 드러내는 태도와 표현 방식을 보여준다" },
          { name: "숨겨진 감정", purpose: "겉모습 뒤에 감춰진 상대방의 내면 감정을 보여준다" },
          { name: "나에 대한 진심", purpose: "상대방이 질문자에게 실제로 느끼는 진심을 보여준다" },
          { name: "머뭇거리는 이유", purpose: "상대방이 마음을 표현하지 못하고 머뭇거리는 이유나 장애물을 보여준다" },
          { name: "앞으로 드러날 마음", purpose: "시간이 지나며 상대방의 마음이 어떻게 드러나고 변화할지를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_reunion_chance",
    categoryGroup: "love",
    topicName: "재회 가능성",
    description: "다시 이어질 수 있을까, 헤어진 상대와의 재회 가능성과 흐름을 읽는 주제",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "재회 가능성", purpose: "지금 이 순간을 기준으로 재회로 이어질 가능성의 크기와 방향을 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "재회 여부", purpose: "재회가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "헤어진 이유", purpose: "두 사람이 헤어지게 된 근본적인 원인과 배경을 보여준다" },
          { name: "상대의 현재 마음", purpose: "상대방이 지금 이 순간 질문자와 관계에 대해 갖고 있는 마음을 보여준다" },
          { name: "재회 가능성과 흐름", purpose: "앞으로 재회로 이어질 가능성과 그 흐름이 어떻게 전개될지를 보여준다" },
        ],
      },
      {
        // [65종 타로 설계표 확정 반영 - 2024] 대표님 마스터 프롬프트 예시 문구를
        // 그대로 반영(docs/tarot_65_topics_design_table.md #3 참조). 기존
        // "헤어진 이유/나의 현재 마음/..." 문구에서 대표님 지정 문구로 교체.
        spreadType: "five_card",
        positions: [
          { name: "이별의 핵심 원인", purpose: "두 사람이 헤어지게 된 근본적인 원인과 배경을 보여준다" },
          { name: "상대방의 현재 마음", purpose: "상대방이 지금 이 순간 질문자와 관계에 대해 갖고 있는 마음을 보여준다" },
          { name: "나에게 남은 감정", purpose: "질문자에게 지금까지 남아있는 이별과 상대에 대한 진짜 감정을 보여준다" },
          { name: "재회를 막는 요인", purpose: "재회를 가로막고 있는 현실적, 감정적 요인을 보여준다" },
          { name: "앞으로의 재회 흐름", purpose: "앞으로 재회로 이어질 가능성과 그 흐름이 어떻게 전개될지를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_job_change",
    categoryGroup: "career",
    topicName: "이직운",
    description: "새로운 문 앞에서, 이직을 고민하거나 준비하는 시기의 흐름과 결과를 읽는 주제",
    // [65종 설계표 §17 반영] career_job_change는 대표님 마스터 프롬프트 §17의
    // YES/NO 12개 확정 목록에 포함된 주제다(docs/tarot_65_topics_design_table.md
    // #15 참조: "YES/NO: Y"). 기존 questionType: "open" / yesNoEnabled: false는
    // 설계표 확정 전 초안 상태의 버그였으므로 yes_no 스프레드를 추가하고
    // yesNoEnabled: true, promptDomain: tarot_yesno로 수정한다.
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "이직운 흐름", purpose: "지금 이직과 관련된 전반적인 기운과 방향을 종합적으로 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "이직 성사 여부", purpose: "이직이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상황", purpose: "지금 질문자가 처한 직장 상황과 이직에 대한 고민의 배경을 보여준다" },
          { name: "이직 시 변화", purpose: "이직을 선택했을 때 실제로 맞이하게 될 변화와 흐름을 보여준다" },
          { name: "결과와 조언", purpose: "이직 시도의 최종적인 결과와 그에 대한 조언을 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 직장 상황", purpose: "지금 질문자가 처한 직장 내 상황과 조건을 보여준다" },
          { name: "이직을 고민하는 이유", purpose: "질문자가 이직을 고민하게 된 근본적인 이유와 동기를 보여준다" },
          { name: "새로운 기회", purpose: "이직을 통해 만나게 될 새로운 기회와 가능성을 보여준다" },
          { name: "장애물/리스크", purpose: "이직 과정에서 마주치게 될 장애물과 리스크 요인을 보여준다" },
          { name: "결과와 조언", purpose: "이직 시도의 최종적인 결과와 그에 대한 조언을 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_fortune",
    categoryGroup: "wealth",
    topicName: "재물운",
    description: "흘러들어오는 것의 흐름, 현재와 앞으로의 금전운을 읽는 주제",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "금전운 흐름", purpose: "지금 재정 전반에 흐르는 기운과 방향을 종합적으로 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 재정 상태", purpose: "지금 질문자가 처한 재정 상태와 자금 흐름의 배경을 보여준다" },
          { name: "변화의 흐름", purpose: "앞으로 재정 상황에 어떤 변화가 다가오는지 그 흐름을 보여준다" },
          { name: "결과와 조언", purpose: "재정 흐름의 최종적인 결과와 그에 대한 조언을 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 재정 상태", purpose: "지금 질문자가 처한 재정 상태와 자금 흐름의 배경을 보여준다" },
          { name: "들어오는 기운", purpose: "앞으로 새롭게 들어오게 될 수입이나 기회의 기운을 보여준다" },
          { name: "나가는 기운", purpose: "지출이나 손실로 빠져나가게 될 기운과 그 원인을 보여준다" },
          { name: "주의할 리스크", purpose: "재정 관리에서 특별히 주의해야 할 리스크 요인을 보여준다" },
          { name: "결과와 조언", purpose: "재정 흐름의 최종적인 결과와 그에 대한 조언을 보여준다" },
        ],
      },
    ],
  },
];

async function main() {
  console.log("[seed_tarot_pilot_topics] 시작...");

  for (const t of TOPICS) {
    const topic = await prisma.tarotTopic.upsert({
      where: { topicKey: t.topicKey },
      update: {
        categoryGroup: t.categoryGroup,
        topicName: t.topicName,
        description: t.description,
        questionType: t.questionType,
        allowedSpreads: JSON.stringify(t.allowedSpreads),
        yesNoEnabled: t.yesNoEnabled,
        isChoiceAb: t.isChoiceAb,
        promptDomain: t.promptDomain,
        updatedBy: "system_seed_tarot_pilot_topics",
      },
      create: {
        topicKey: t.topicKey,
        categoryGroup: t.categoryGroup,
        topicName: t.topicName,
        description: t.description,
        questionType: t.questionType,
        allowedSpreads: JSON.stringify(t.allowedSpreads),
        yesNoEnabled: t.yesNoEnabled,
        isChoiceAb: t.isChoiceAb,
        promptDomain: t.promptDomain,
        createdBy: "system_seed_tarot_pilot_topics",
        updatedBy: "system_seed_tarot_pilot_topics",
      },
    });

    for (const spread of t.spreads) {
      for (let i = 0; i < spread.positions.length; i++) {
        const pos = spread.positions[i];
        await prisma.tarotPosition.upsert({
          where: {
            topicId_spreadType_positionIndex: {
              topicId: topic.id,
              spreadType: spread.spreadType,
              positionIndex: i,
            },
          },
          update: {
            positionName: pos.name,
            positionPurpose: pos.purpose,
          },
          create: {
            topicId: topic.id,
            spreadType: spread.spreadType,
            positionIndex: i,
            positionName: pos.name,
            positionPurpose: pos.purpose,
          },
        });
      }
    }
    console.log(`[seed_tarot_pilot_topics] "${t.topicName}"(${t.topicKey}) 토픽 + 포지션(1/3/5카드) 완료`);
  }

  const topicCount = await prisma.tarotTopic.count();
  const positionCount = await prisma.tarotPosition.count();
  console.log(`[seed_tarot_pilot_topics] 완료. tarot_topics=${topicCount}, tarot_positions=${positionCount}`);
}

main()
  .catch((e) => {
    console.error("[seed_tarot_pilot_topics] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
