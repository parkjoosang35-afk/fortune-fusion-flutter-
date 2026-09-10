// [신통방통 타로 65종 주제 연동 - 나머지 60개 주제 시딩 (A/B 1개 제외 59개)]
// docs/tarot_65_topics_design_table.md 확정본(v1.0, 대표님 "진행" 승인)을 그대로
// TarotTopic/TarotPosition에 반영한다. 5개 파일럿(썸의흐름/상대의속마음/재회가능성/
// 이직운/재물운)은 seed_tarot_pilot_topics.ts에서 별도 관리(중복 실행 방지).
// daily_direction_of_choice(A/B 양자택일)는 카드추첨 구조가 근본적으로 다르므로
// 이번 시딩에서 제외 — 별도 스프레드타입(choice_ab) 설계 후 추가 예정.
//
// [position_purpose 품질 참고] 설계표 문서의 60개 신규 주제는 포지션별 상세 해석
// 목적문 대신 포지션명만 부여되어 있어, 이 스크립트가 한국어 조사(와/과) 규칙을
// 적용해 "{포지션명}와/과 관련된 흐름과 의미를 보여준다" 형태로 자동 생성했다.
// AI 해석 품질을 더 높이려면 추후 관리자 CMS에서 포지션별 purpose 문구를 더
// 구체적으로 다듬는 2차 작업이 필요하다(5개 파일럿은 이미 수작업 문구로 완성됨).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

interface PositionSeed {
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
    topicKey: "love_will_they_contact",
    categoryGroup: "love",
    topicName: "연락이 올까",
    description: "상대에게서 연락이 올지, 그 시기와 계기를 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "연락 가능성", purpose: "연락 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "상대의 현재 상태", purpose: "상대의 현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "연락을 미루는 이유", purpose: "연락을 미루는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "연락이 올 가능성과 흐름", purpose: "연락이 올 가능성과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "상대의 현재 마음", purpose: "상대의 현재 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "연락을 고민하는 이유", purpose: "연락을 고민하는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "방해 요인", purpose: "방해 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "계기가 될 사건", purpose: "계기가 될 사건과 관련된 흐름과 의미를 보여준다" },
          { name: "연락 가능성과 흐름", purpose: "연락 가능성과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "연락이 올까 여부", purpose: "연락이 올까가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_confession_timing",
    categoryGroup: "love",
    topicName: "고백 타이밍",
    description: "지금이 마음을 고백할 적절한 시점인지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "고백 타이밍", purpose: "고백 타이밍과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계 분위기", purpose: "현재 관계 분위기와 관련된 흐름과 의미를 보여준다" },
          { name: "상대의 마음 준비도", purpose: "상대의 마음 준비도와 관련된 흐름과 의미를 보여준다" },
          { name: "고백 시 결과 흐름", purpose: "고백 시 결과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "나의 마음 상태", purpose: "나의 마음 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "상대의 마음 준비도", purpose: "상대의 마음 준비도와 관련된 흐름과 의미를 보여준다" },
          { name: "지금 시점의 적절성", purpose: "지금 시점의 적절성과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 변수", purpose: "주의할 변수와 관련된 흐름과 의미를 보여준다" },
          { name: "고백 이후 흐름", purpose: "고백 이후 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "고백 타이밍 여부", purpose: "고백 타이밍이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_fortune",
    categoryGroup: "love",
    topicName: "연애운",
    description: "다가올 연애운의 전반적인 흐름과 기회를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "연애운 흐름", purpose: "연애운 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 연애 상태", purpose: "현재 연애 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 기회/변화", purpose: "다가오는 기회/변화와 관련된 흐름과 의미를 보여준다" },
          { name: "연애운의 전체 흐름", purpose: "연애운의 전체 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 상태", purpose: "현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "나의 매력 포인트", purpose: "나의 매력 포인트와 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 인연/기회", purpose: "다가오는 인연/기회와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "연애운의 흐름", purpose: "연애운의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_marriage_chance",
    categoryGroup: "love",
    topicName: "결혼 가능성",
    description: "지금의 상대 또는 현재 흐름에서 결혼으로 이어질 가능성을 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "결혼 가능성", purpose: "결혼 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계의 안정도", purpose: "현재 관계의 안정도와 관련된 흐름과 의미를 보여준다" },
          { name: "결혼을 향한 흐름/변수", purpose: "결혼을 향한 흐름/변수와 관련된 흐름과 의미를 보여준다" },
          { name: "결혼 가능성과 시기", purpose: "결혼 가능성과 시기와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "상대의 결혼에 대한 마음", purpose: "상대의 결혼에 대한 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "나의 준비도", purpose: "나의 준비도와 관련된 흐름과 의미를 보여준다" },
          { name: "극복해야 할 장애물", purpose: "극복해야 할 장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "결혼 가능성과 흐름", purpose: "결혼 가능성과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "결혼 가능성 여부", purpose: "결혼 가능성이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_relationship_future",
    categoryGroup: "love",
    topicName: "관계의 미래",
    description: "지금의 관계가 앞으로 어떤 방향으로 전개될지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "관계의 방향", purpose: "관계의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로 다가올 변화", purpose: "앞으로 다가올 변화와 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 최종 방향", purpose: "관계의 최종 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 관계의 기반", purpose: "현재 관계의 기반과 관련된 흐름과 의미를 보여준다" },
          { name: "서로에 대한 신뢰", purpose: "서로에 대한 신뢰와 관련된 흐름과 의미를 보여준다" },
          { name: "다가올 변화/시험", purpose: "다가올 변화/시험과 관련된 흐름과 의미를 보여준다" },
          { name: "관계를 지속시키는 힘", purpose: "관계를 지속시키는 힘과 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 미래 방향", purpose: "관계의 미래 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_secret_relationship",
    categoryGroup: "love",
    topicName: "비밀연애",
    description: "숨기고 있는 연애의 흐름과 앞으로의 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "비밀연애의 흐름", purpose: "비밀연애의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "숨기는 이유", purpose: "숨기는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 현재 온도", purpose: "관계의 현재 온도와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "시작된 배경", purpose: "시작된 배경과 관련된 흐름과 의미를 보여준다" },
          { name: "서로의 진심", purpose: "서로의 진심과 관련된 흐름과 의미를 보여준다" },
          { name: "숨김으로 인한 긴장", purpose: "숨김으로 인한 긴장과 관련된 흐름과 의미를 보여준다" },
          { name: "공개 가능성", purpose: "공개 가능성과 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 향방", purpose: "관계의 향방과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_long_distance",
    categoryGroup: "love",
    topicName: "장거리 연애",
    description: "거리를 둔 관계가 유지될 수 있을지, 그 흐름을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "장거리 연애 흐름", purpose: "장거리 연애 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계의 온도", purpose: "현재 관계의 온도와 관련된 흐름과 의미를 보여준다" },
          { name: "거리로 인한 어려움", purpose: "거리로 인한 어려움과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "서로의 마음", purpose: "서로의 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "거리가 주는 영향", purpose: "거리가 주는 영향과 관련된 흐름과 의미를 보여준다" },
          { name: "소통의 흐름", purpose: "소통의 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "위기 요인", purpose: "위기 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 향방", purpose: "관계의 향방과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_lingering_after_breakup",
    categoryGroup: "love",
    topicName: "이별 후 미련",
    description: "이별 후 남은 미련의 정체와 앞으로 이 감정을 어떻게 다룰지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "남은 미련", purpose: "남은 미련과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "미련의 원인", purpose: "미련의 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "상대에 대한 감정", purpose: "상대에 대한 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "이 감정의 앞으로", purpose: "이 감정의 앞으로와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "이별 당시의 감정", purpose: "이별 당시의 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "지금 남은 감정", purpose: "지금 남은 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "미련의 근본 원인", purpose: "미련의 근본 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "정리에 필요한 것", purpose: "정리에 필요한 것과 관련된 흐름과 의미를 보여준다" },
          { name: "감정의 향방", purpose: "감정의 향방과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_destined_connection",
    categoryGroup: "love",
    topicName: "운명의 인연",
    description: "지금 곁에 있거나 다가올 사람이 운명적인 인연인지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "운명의 신호", purpose: "운명의 신호와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "인연이 시작된 이유", purpose: "인연이 시작된 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "서로에게 미치는 영향", purpose: "서로에게 미치는 영향과 관련된 흐름과 의미를 보여준다" },
          { name: "운명적 흐름", purpose: "운명적 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "만남의 배경", purpose: "만남의 배경과 관련된 흐름과 의미를 보여준다" },
          { name: "서로에게 주는 의미", purpose: "서로에게 주는 의미와 관련된 흐름과 의미를 보여준다" },
          { name: "서로를 끌어당기는 힘", purpose: "서로를 끌어당기는 힘과 관련된 흐름과 의미를 보여준다" },
          { name: "시험이 될 사건", purpose: "시험이 될 사건과 관련된 흐름과 의미를 보여준다" },
          { name: "운명적 흐름의 결말", purpose: "운명적 흐름의 결말과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_next_chapter_of_crush",
    categoryGroup: "love",
    topicName: "짝사랑의 다음 장",
    description: "혼자만의 마음이 다음 단계로 나아갈 수 있을지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "다음 장의 방향", purpose: "다음 장의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 내 마음", purpose: "현재 내 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "상대와의 거리", purpose: "상대와의 거리와 관련된 흐름과 의미를 보여준다" },
          { name: "다음 장의 흐름", purpose: "다음 장의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 내 마음", purpose: "현재 내 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "상대가 나를 보는 시선", purpose: "상대가 나를 보는 시선과 관련된 흐름과 의미를 보여준다" },
          { name: "거리를 좁힐 기회", purpose: "거리를 좁힐 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "다음 장의 방향", purpose: "다음 장의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "love_timing_of_fate",
    categoryGroup: "love",
    topicName: "인연의 타이밍",
    description: "지금이 인연을 만나거나 발전시킬 적절한 시점인지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot_love",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "인연의 타이밍", purpose: "인연의 타이밍과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 기회", purpose: "다가오는 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "타이밍의 흐름", purpose: "타이밍의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 나의 상태", purpose: "현재 나의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 신호", purpose: "다가오는 신호와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 시기", purpose: "주의할 시기와 관련된 흐름과 의미를 보여준다" },
          { name: "놓치면 안 될 기회", purpose: "놓치면 안 될 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "타이밍의 결론", purpose: "타이밍의 결론과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_interview_result",
    categoryGroup: "career",
    topicName: "면접 결과",
    description: "준비한 면접이 좋은 결과로 이어질지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "면접 결과", purpose: "면접 결과와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "준비 상태", purpose: "준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "면접 당일 분위기", purpose: "면접 당일 분위기와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "준비 상태", purpose: "준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "나의 강점", purpose: "나의 강점과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 약점", purpose: "주의할 약점과 관련된 흐름과 의미를 보여준다" },
          { name: "면접관과의 케미", purpose: "면접관과의 케미와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "면접 결과 여부", purpose: "면접 결과가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_boss_relationship",
    categoryGroup: "career",
    topicName: "상사와의 관계",
    description: "상사와의 관계에서 겪는 어려움과 앞으로의 흐름을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "관계의 흐름", purpose: "관계의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "갈등/긴장의 원인", purpose: "갈등/긴장의 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "상사가 보는 나", purpose: "상사가 보는 나와 관련된 흐름과 의미를 보여준다" },
          { name: "갈등의 근본 원인", purpose: "갈등의 근본 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "개선의 열쇠", purpose: "개선의 열쇠와 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 향방", purpose: "관계의 향방과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_coworker_flow",
    categoryGroup: "career",
    topicName: "동료와의 흐름",
    description: "동료들과 함께 걷는 길의 흐름과 협업의 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "협업의 흐름", purpose: "협업의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "협업 중 변수", purpose: "협업 중 변수와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 관계 상태", purpose: "현재 관계 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "나의 역할", purpose: "나의 역할과 관련된 흐름과 의미를 보여준다" },
          { name: "잠재된 갈등 요인", purpose: "잠재된 갈등 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "협력의 기회", purpose: "협력의 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "관계의 향방", purpose: "관계의 향방과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_project_result",
    categoryGroup: "career",
    topicName: "프로젝트 결과",
    description: "진행 중인 프로젝트가 좋은 결과로 마무리될지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "프로젝트 결과", purpose: "프로젝트 결과와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 진행 상태", purpose: "현재 진행 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "변수와 장애물", purpose: "변수와 장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 진행 상태", purpose: "현재 진행 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "강점/기회", purpose: "강점/기회와 관련된 흐름과 의미를 보여준다" },
          { name: "리스크/장애물", purpose: "리스크/장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "주변의 협조", purpose: "주변의 협조와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "프로젝트 결과 여부", purpose: "프로젝트 결과가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_promotion_chance",
    categoryGroup: "career",
    topicName: "승진 가능성",
    description: "지금 승진으로 이어질 가능성이 있는지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "승진 가능성", purpose: "승진 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 평가 상태", purpose: "현재 평가 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "경쟁/변수", purpose: "경쟁/변수와 관련된 흐름과 의미를 보여준다" },
          { name: "가능성과 흐름", purpose: "가능성과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 성과", purpose: "현재 성과와 관련된 흐름과 의미를 보여준다" },
          { name: "주변의 평가", purpose: "주변의 평가와 관련된 흐름과 의미를 보여준다" },
          { name: "경쟁 요소", purpose: "경쟁 요소와 관련된 흐름과 의미를 보여준다" },
          { name: "결정적 기회", purpose: "결정적 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "가능성과 흐름", purpose: "가능성과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "승진 가능성 여부", purpose: "승진 가능성이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_startup_fortune",
    categoryGroup: "career",
    topicName: "창업운",
    description: "새로 시작하려는 사업의 흐름과 전망을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "창업운 흐름", purpose: "창업운 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 준비 상태", purpose: "현재 준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "시작 후 변화", purpose: "시작 후 변화와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 준비 상태", purpose: "현재 준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "강점/기회", purpose: "강점/기회와 관련된 흐름과 의미를 보여준다" },
          { name: "리스크", purpose: "리스크와 관련된 흐름과 의미를 보여준다" },
          { name: "초기 흐름", purpose: "초기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_freelance_fortune",
    categoryGroup: "career",
    topicName: "프리랜서 운",
    description: "혼자 걷는 프리랜서로서의 흐름과 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "프리랜서 운 흐름", purpose: "프리랜서 운 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "변화/기회", purpose: "변화/기회와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "강점", purpose: "강점과 관련된 흐름과 의미를 보여준다" },
          { name: "불안 요소", purpose: "불안 요소와 관련된 흐름과 의미를 보여준다" },
          { name: "새로운 기회", purpose: "새로운 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_current_job_future",
    categoryGroup: "career",
    topicName: "현재 직장의 미래",
    description: "지금 다니는 직장이 앞으로 안전할지, 어떤 변화가 있을지 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "직장의 미래", purpose: "직장의 미래와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 직장 상태", purpose: "현재 직장 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "다가올 변화", purpose: "다가올 변화와 관련된 흐름과 의미를 보여준다" },
          { name: "미래 흐름", purpose: "미래 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 안정성", purpose: "현재 안정성과 관련된 흐름과 의미를 보여준다" },
          { name: "주변 변화 조짐", purpose: "주변 변화 조짐과 관련된 흐름과 의미를 보여준다" },
          { name: "나의 입지", purpose: "나의 입지와 관련된 흐름과 의미를 보여준다" },
          { name: "위기/기회 요인", purpose: "위기/기회 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "미래 흐름", purpose: "미래 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_yearly_flow",
    categoryGroup: "career",
    topicName: "올해 커리어 흐름",
    description: "한 해 동안의 일·커리어 흐름과 중요한 시기를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "올해의 흐름", purpose: "올해의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "상반기 흐름", purpose: "상반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "하반기 흐름", purpose: "하반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "올해의 전체 방향", purpose: "올해의 전체 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 위치", purpose: "현재 위치와 관련된 흐름과 의미를 보여준다" },
          { name: "상반기 흐름", purpose: "상반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중요한 전환점", purpose: "중요한 전환점과 관련된 흐름과 의미를 보여준다" },
          { name: "하반기 흐름", purpose: "하반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "올해의 전체 방향", purpose: "올해의 전체 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_aptitude_direction",
    categoryGroup: "career",
    topicName: "적성과 방향",
    description: "나에게 맞는 일의 방향과 적성을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "적성의 방향", purpose: "적성의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 나의 강점", purpose: "현재 나의 강점과 관련된 흐름과 의미를 보여준다" },
          { name: "맞지 않는 부분", purpose: "맞지 않는 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "적합한 방향", purpose: "적합한 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 강점", purpose: "현재 강점과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 잠재력", purpose: "숨겨진 잠재력과 관련된 흐름과 의미를 보여준다" },
          { name: "맞지 않는 환경", purpose: "맞지 않는 환경과 관련된 흐름과 의미를 보여준다" },
          { name: "끌리는 방향", purpose: "끌리는 방향과 관련된 흐름과 의미를 보여준다" },
          { name: "적합한 방향", purpose: "적합한 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "career_new_sprout",
    categoryGroup: "career",
    topicName: "커리어 새싹",
    description: "이제 막 시작하는 일이나 경력의 초기 운을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "새싹의 기운", purpose: "새싹의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "시작하는 마음", purpose: "시작하는 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "초기 장애물", purpose: "초기 장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "성장의 흐름", purpose: "성장의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "시작하는 마음", purpose: "시작하는 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "주변의 지원", purpose: "주변의 지원과 관련된 흐름과 의미를 보여준다" },
          { name: "초기 장애물", purpose: "초기 장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "성장의 기회", purpose: "성장의 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "성장의 흐름", purpose: "성장의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_spending_flow",
    categoryGroup: "wealth",
    topicName: "소비 흐름",
    description: "지금 새어나가는 소비의 패턴과 흐름을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "소비 흐름", purpose: "소비 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 소비 패턴", purpose: "현재 소비 패턴과 관련된 흐름과 의미를 보여준다" },
          { name: "새어나가는 원인", purpose: "새어나가는 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 소비 패턴", purpose: "현재 소비 패턴과 관련된 흐름과 의미를 보여준다" },
          { name: "새어나가는 지점", purpose: "새어나가는 지점과 관련된 흐름과 의미를 보여준다" },
          { name: "심리적 원인", purpose: "심리적 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "조절의 기회", purpose: "조절의 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_investment_flow",
    categoryGroup: "wealth",
    topicName: "투자 흐름",
    description: "고민 중인 투자가 좋은 흐름으로 이어질지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "투자 흐름", purpose: "투자 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "변수/리스크", purpose: "변수/리스크와 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 판단", purpose: "현재 판단과 관련된 흐름과 의미를 보여준다" },
          { name: "기회 요인", purpose: "기회 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "리스크 요인", purpose: "리스크 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "타이밍", purpose: "타이밍과 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "투자 흐름 여부", purpose: "투자 흐름이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_contract_success",
    categoryGroup: "wealth",
    topicName: "계약 성사 가능성",
    description: "진행 중인 계약이 성사될 수 있을지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "계약 성사 가능성", purpose: "계약 성사 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 협의 상태", purpose: "현재 협의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "변수/장애물", purpose: "변수/장애물과 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 협의 상태", purpose: "현재 협의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "상대측 태도", purpose: "상대측 태도와 관련된 흐름과 의미를 보여준다" },
          { name: "걸림돌", purpose: "걸림돌과 관련된 흐름과 의미를 보여준다" },
          { name: "유리한 조건", purpose: "유리한 조건과 관련된 흐름과 의미를 보여준다" },
          { name: "결과와 조언", purpose: "결과와 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "계약 성사 가능성 여부", purpose: "계약 성사 가능성이 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_incoming_timing",
    categoryGroup: "wealth",
    topicName: "돈이 들어오는 시기",
    description: "기대하는 수입이나 자금이 들어올 시기를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "유입 시기", purpose: "유입 시기와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상태", purpose: "현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 기회", purpose: "다가오는 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "시기와 흐름", purpose: "시기와 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 상태", purpose: "현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "기다리는 이유", purpose: "기다리는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "다가오는 신호", purpose: "다가오는 신호와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 지연 요인", purpose: "주의할 지연 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "시기와 흐름", purpose: "시기와 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_spending_warning",
    categoryGroup: "wealth",
    topicName: "지출 경고",
    description: "앞으로 주의해야 할 지출과 위험 요인을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "지출 경고", purpose: "지출 경고와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 재정 상태", purpose: "현재 재정 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "위험 신호", purpose: "위험 신호와 관련된 흐름과 의미를 보여준다" },
          { name: "대처 방향", purpose: "대처 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 재정 상태", purpose: "현재 재정 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "경고의 근원", purpose: "경고의 근원과 관련된 흐름과 의미를 보여준다" },
          { name: "새어나갈 지점", purpose: "새어나갈 지점과 관련된 흐름과 의미를 보여준다" },
          { name: "대비할 방법", purpose: "대비할 방법과 관련된 흐름과 의미를 보여준다" },
          { name: "대처 방향", purpose: "대처 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_solution_hint",
    categoryGroup: "wealth",
    topicName: "금전 문제 해결 힌트",
    description: "막힌 금전 문제를 풀 수 있는 실마리를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "해결의 힌트", purpose: "해결의 힌트와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 문제 상태", purpose: "현재 문제 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 원인", purpose: "숨겨진 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "해결의 방향", purpose: "해결의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 문제 상태", purpose: "현재 문제 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "근본 원인", purpose: "근본 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 기회", purpose: "숨겨진 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 함정", purpose: "주의할 함정과 관련된 흐름과 의미를 보여준다" },
          { name: "해결의 방향", purpose: "해결의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_asset_direction",
    categoryGroup: "wealth",
    topicName: "자산의 방향",
    description: "지금 가진 자산을 어떻게 움직여야 할지 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "자산의 방향", purpose: "자산의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 자산 상태", purpose: "현재 자산 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "변화의 필요성", purpose: "변화의 필요성과 관련된 흐름과 의미를 보여준다" },
          { name: "방향과 흐름", purpose: "방향과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 자산 상태", purpose: "현재 자산 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "유지해야 할 부분", purpose: "유지해야 할 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "옮겨야 할 부분", purpose: "옮겨야 할 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "위험 요인", purpose: "위험 요인과 관련된 흐름과 의미를 보여준다" },
          { name: "방향과 흐름", purpose: "방향과 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "wealth_harvest_timing",
    categoryGroup: "wealth",
    topicName: "수확의 시기",
    description: "지금까지의 노력이 결실을 맺는 시기를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "수확의 시기", purpose: "수확의 시기와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 준비 상태", purpose: "현재 준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "결실이 다가오는 신호", purpose: "결실이 다가오는 신호와 관련된 흐름과 의미를 보여준다" },
          { name: "수확의 시기", purpose: "수확의 시기와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 준비 상태", purpose: "현재 준비 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "결실의 조짐", purpose: "결실의 조짐과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 변수", purpose: "주의할 변수와 관련된 흐름과 의미를 보여준다" },
          { name: "도움이 될 기회", purpose: "도움이 될 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "수확의 시기", purpose: "수확의 시기와 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_today_tarot",
    categoryGroup: "daily",
    topicName: "오늘의 타로",
    description: "오늘 하루 전반의 기운과 조언을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "오늘의 카드", purpose: "오늘의 카드와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "오늘의 시작", purpose: "오늘의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "오늘의 중심", purpose: "오늘의 중심과 관련된 흐름과 의미를 보여준다" },
          { name: "오늘의 마무리", purpose: "오늘의 마무리와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "오늘의 시작", purpose: "오늘의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "오늘의 중심", purpose: "오늘의 중심과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 순간", purpose: "주의할 순간과 관련된 흐름과 의미를 보여준다" },
          { name: "찾아올 기회", purpose: "찾아올 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "오늘의 마무리", purpose: "오늘의 마무리와 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_this_week",
    categoryGroup: "daily",
    topicName: "이번 주 흐름",
    description: "이번 한 주 동안의 전반적인 흐름을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "이번 주의 기운", purpose: "이번 주의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "주 초반 흐름", purpose: "주 초반 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "주 중반 흐름", purpose: "주 중반 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "주 후반 흐름", purpose: "주 후반 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "주 초반", purpose: "주 초반과 관련된 흐름과 의미를 보여준다" },
          { name: "중요한 사건", purpose: "중요한 사건과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 요일", purpose: "주의할 요일과 관련된 흐름과 의미를 보여준다" },
          { name: "찾아올 기회", purpose: "찾아올 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "주 후반", purpose: "주 후반과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_this_month",
    categoryGroup: "daily",
    topicName: "이번 달 흐름",
    description: "이번 한 달 동안의 흐름과 중요한 시기를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "이번 달의 기운", purpose: "이번 달의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "초반 흐름", purpose: "초반 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중반 흐름", purpose: "중반 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "후반 흐름", purpose: "후반 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "초반 흐름", purpose: "초반 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중요한 전환점", purpose: "중요한 전환점과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 시기", purpose: "주의할 시기와 관련된 흐름과 의미를 보여준다" },
          { name: "찾아올 기회", purpose: "찾아올 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "후반 흐름", purpose: "후반 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_this_year",
    categoryGroup: "daily",
    topicName: "올해의 흐름",
    description: "올 한 해를 관통하는 전체적인 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "올해의 기운", purpose: "올해의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "상반기 흐름", purpose: "상반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "하반기 흐름", purpose: "하반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "올해의 전체 메시지", purpose: "올해의 전체 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 위치", purpose: "현재 위치와 관련된 흐름과 의미를 보여준다" },
          { name: "상반기 흐름", purpose: "상반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중요한 전환점", purpose: "중요한 전환점과 관련된 흐름과 의미를 보여준다" },
          { name: "하반기 흐름", purpose: "하반기 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "올해의 전체 메시지", purpose: "올해의 전체 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_message_needed_now",
    categoryGroup: "daily",
    topicName: "지금 필요한 메시지",
    description: "지금 이 순간 나에게 필요한 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "지금의 메시지", purpose: "지금의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 상태", purpose: "지금의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 조언", purpose: "필요한 조언과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 상태", purpose: "지금의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "놓치고 있는 것", purpose: "놓치고 있는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 조언", purpose: "필요한 조언과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_things_to_watch",
    categoryGroup: "daily",
    topicName: "조심할 일",
    description: "앞으로 다가올 조심해야 할 일들을 미리 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "조심할 일", purpose: "조심할 일과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "경계할 부분", purpose: "경계할 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "대처 방향", purpose: "대처 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 상황", purpose: "현재 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "경계할 부분", purpose: "경계할 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "위험이 다가오는 시점", purpose: "위험이 다가오는 시점과 관련된 흐름과 의미를 보여준다" },
          { name: "대비할 방법", purpose: "대비할 방법과 관련된 흐름과 의미를 보여준다" },
          { name: "대처 방향", purpose: "대처 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_luck_point",
    categoryGroup: "daily",
    topicName: "행운 포인트",
    description: "오늘/지금 숨어있는 행운의 포인트를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "행운 포인트", purpose: "행운 포인트와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 상태", purpose: "현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "행운이 숨은 곳", purpose: "행운이 숨은 곳과 관련된 흐름과 의미를 보여준다" },
          { name: "활용 방향", purpose: "활용 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 상태", purpose: "현재 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "행운의 신호", purpose: "행운의 신호와 관련된 흐름과 의미를 보여준다" },
          { name: "숨은 행운의 위치", purpose: "숨은 행운의 위치와 관련된 흐름과 의미를 보여준다" },
          { name: "활용할 방법", purpose: "활용할 방법과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 흐름", purpose: "앞으로의 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_tomorrow_feeling",
    categoryGroup: "daily",
    topicName: "내일의 예감",
    description: "하루 앞서 내일의 기운을 미리 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "내일의 예감", purpose: "내일의 예감과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "내일의 시작", purpose: "내일의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "내일의 중심", purpose: "내일의 중심과 관련된 흐름과 의미를 보여준다" },
          { name: "내일의 마무리", purpose: "내일의 마무리와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "내일의 시작", purpose: "내일의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 순간", purpose: "주의할 순간과 관련된 흐름과 의미를 보여준다" },
          { name: "찾아올 기회", purpose: "찾아올 기회와 관련된 흐름과 의미를 보여준다" },
          { name: "사람과의 관계", purpose: "사람과의 관계와 관련된 흐름과 의미를 보여준다" },
          { name: "내일의 마무리", purpose: "내일의 마무리와 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "daily_quarterly_flow",
    categoryGroup: "daily",
    topicName: "분기의 흐름",
    description: "앞으로 석 달간의 흐름을 미리 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "분기의 기운", purpose: "분기의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "첫 달 흐름", purpose: "첫 달 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중간 달 흐름", purpose: "중간 달 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "마지막 달 흐름", purpose: "마지막 달 흐름과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 위치", purpose: "현재 위치와 관련된 흐름과 의미를 보여준다" },
          { name: "첫 달 흐름", purpose: "첫 달 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "중요한 전환점", purpose: "중요한 전환점과 관련된 흐름과 의미를 보여준다" },
          { name: "마지막 달 흐름", purpose: "마지막 달 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "분기 전체 메시지", purpose: "분기 전체 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_current_heart",
    categoryGroup: "emotion",
    topicName: "지금 내 마음",
    description: "지금 내 안에 흐르는 감정의 실체를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "지금 내 마음", purpose: "지금 내 마음과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "겉으로 드러나는 감정", purpose: "겉으로 드러나는 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 진짜 감정", purpose: "숨겨진 진짜 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "이 감정이 향하는 곳", purpose: "이 감정이 향하는 곳과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "겉으로 드러나는 감정", purpose: "겉으로 드러나는 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 진짜 감정", purpose: "숨겨진 진짜 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "이 감정의 원인", purpose: "이 감정의 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 것", purpose: "필요한 것과 관련된 흐름과 의미를 보여준다" },
          { name: "감정이 향하는 곳", purpose: "감정이 향하는 곳과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_anxiety_root",
    categoryGroup: "emotion",
    topicName: "불안의 원인",
    description: "지금 느끼는 불안의 근본 원인을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "불안의 원인", purpose: "불안의 원인과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 불안의 모습", purpose: "현재 불안의 모습과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 원인", purpose: "숨겨진 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "해소의 방향", purpose: "해소의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 불안의 모습", purpose: "현재 불안의 모습과 관련된 흐름과 의미를 보여준다" },
          { name: "표면적 원인", purpose: "표면적 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 근본 원인", purpose: "숨겨진 근본 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "안정을 주는 요소", purpose: "안정을 주는 요소와 관련된 흐름과 의미를 보여준다" },
          { name: "해소의 방향", purpose: "해소의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_need_comfort",
    categoryGroup: "emotion",
    topicName: "위로가 필요한 순간",
    description: "지금 필요한 위로와 그것을 얻는 방법을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "필요한 위로", purpose: "필요한 위로와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 마음 상태", purpose: "지금의 마음 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "위로가 필요한 이유", purpose: "위로가 필요한 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "위로를 얻는 방법", purpose: "위로를 얻는 방법과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 마음 상태", purpose: "지금의 마음 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "위로가 필요한 이유", purpose: "위로가 필요한 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "마음의 짐", purpose: "마음의 짐과 관련된 흐름과 의미를 보여준다" },
          { name: "도움을 줄 존재", purpose: "도움을 줄 존재와 관련된 흐름과 의미를 보여준다" },
          { name: "위로를 얻는 방법", purpose: "위로를 얻는 방법과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_to_let_go",
    categoryGroup: "emotion",
    topicName: "놓아야 할 감정",
    description: "이제 흘려보내야 할 감정과 그 방법을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "놓아야 할 감정", purpose: "놓아야 할 감정과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "붙잡고 있는 감정", purpose: "붙잡고 있는 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "붙잡는 이유", purpose: "붙잡는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "놓아주는 방향", purpose: "놓아주는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "붙잡고 있는 감정", purpose: "붙잡고 있는 감정과 관련된 흐름과 의미를 보여준다" },
          { name: "붙잡는 이유", purpose: "붙잡는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "이 감정이 주는 영향", purpose: "이 감정이 주는 영향과 관련된 흐름과 의미를 보여준다" },
          { name: "놓아줄 계기", purpose: "놓아줄 계기와 관련된 흐름과 의미를 보여준다" },
          { name: "놓아주는 방향", purpose: "놓아주는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_can_i_restart",
    categoryGroup: "emotion",
    topicName: "다시 시작할 수 있을까",
    description: "지금의 상황에서 다시 시작할 수 있는지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "다시 시작할 가능성", purpose: "다시 시작할 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 마음 상태", purpose: "현재 마음 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "다시 시작을 막는 것", purpose: "다시 시작을 막는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "다시 시작할 가능성", purpose: "다시 시작할 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 마음 상태", purpose: "현재 마음 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "과거의 영향", purpose: "과거의 영향과 관련된 흐름과 의미를 보여준다" },
          { name: "다시 시작을 막는 것", purpose: "다시 시작을 막는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 용기/조건", purpose: "필요한 용기/조건과 관련된 흐름과 의미를 보여준다" },
          { name: "다시 시작할 가능성", purpose: "다시 시작할 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "다시 시작할 수 있을까 여부", purpose: "다시 시작할 수 있을까가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_advice_for_myself",
    categoryGroup: "emotion",
    topicName: "나를 위한 조언",
    description: "지금 스스로에게 건네야 할 조언을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "나를 위한 조언", purpose: "나를 위한 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 나의 상태", purpose: "현재 나의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "놓치고 있는 것", purpose: "놓치고 있는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "나를 위한 조언", purpose: "나를 위한 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 나의 상태", purpose: "현재 나의 상태와 관련된 흐름과 의미를 보여준다" },
          { name: "잘하고 있는 부분", purpose: "잘하고 있는 부분과 관련된 흐름과 의미를 보여준다" },
          { name: "놓치고 있는 것", purpose: "놓치고 있는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 변화", purpose: "필요한 변화와 관련된 흐름과 의미를 보여준다" },
          { name: "나를 위한 조언", purpose: "나를 위한 조언과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_hidden_talent",
    categoryGroup: "emotion",
    topicName: "숨은 재능",
    description: "아직 발견되지 않은 나의 재능을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "숨은 재능", purpose: "숨은 재능과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 드러난 강점", purpose: "현재 드러난 강점과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 재능", purpose: "숨겨진 재능과 관련된 흐름과 의미를 보여준다" },
          { name: "재능을 발견할 방향", purpose: "재능을 발견할 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 드러난 강점", purpose: "현재 드러난 강점과 관련된 흐름과 의미를 보여준다" },
          { name: "숨겨진 재능", purpose: "숨겨진 재능과 관련된 흐름과 의미를 보여준다" },
          { name: "재능이 숨은 이유", purpose: "재능이 숨은 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "발견의 계기", purpose: "발견의 계기와 관련된 흐름과 의미를 보여준다" },
          { name: "재능을 발견할 방향", purpose: "재능을 발견할 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_inner_growth",
    categoryGroup: "emotion",
    topicName: "내면 성장 메시지",
    description: "지금의 나를 성장시키는 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "성장의 메시지", purpose: "성장의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "현재 나의 단계", purpose: "현재 나의 단계와 관련된 흐름과 의미를 보여준다" },
          { name: "성장을 위한 과제", purpose: "성장을 위한 과제와 관련된 흐름과 의미를 보여준다" },
          { name: "성장의 방향", purpose: "성장의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "현재 나의 단계", purpose: "현재 나의 단계와 관련된 흐름과 의미를 보여준다" },
          { name: "이미 이룬 성장", purpose: "이미 이룬 성장과 관련된 흐름과 의미를 보여준다" },
          { name: "성장을 위한 과제", purpose: "성장을 위한 과제와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 함정", purpose: "주의할 함정과 관련된 흐름과 의미를 보여준다" },
          { name: "성장의 방향", purpose: "성장의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_wave",
    categoryGroup: "emotion",
    topicName: "감정의 파동",
    description: "지금 마음이 흔들리는 결과 그 흐름을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "감정의 파동", purpose: "감정의 파동과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "흔들림의 시작", purpose: "흔들림의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "흔들림의 정점", purpose: "흔들림의 정점과 관련된 흐름과 의미를 보여준다" },
          { name: "파동이 가라앉는 방향", purpose: "파동이 가라앉는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "흔들림의 시작", purpose: "흔들림의 시작과 관련된 흐름과 의미를 보여준다" },
          { name: "흔들림의 원인", purpose: "흔들림의 원인과 관련된 흐름과 의미를 보여준다" },
          { name: "지금 정점", purpose: "지금 정점과 관련된 흐름과 의미를 보여준다" },
          { name: "안정을 줄 요소", purpose: "안정을 줄 요소와 관련된 흐름과 의미를 보여준다" },
          { name: "파동이 가라앉는 방향", purpose: "파동이 가라앉는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "emotion_time_lag",
    categoryGroup: "emotion",
    topicName: "마음의 시차",
    description: "지금 마음이 머무는 시간과 현실과의 시차를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "마음의 시차", purpose: "마음의 시차와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "마음이 머무는 곳", purpose: "마음이 머무는 곳과 관련된 흐름과 의미를 보여준다" },
          { name: "시차가 주는 영향", purpose: "시차가 주는 영향과 관련된 흐름과 의미를 보여준다" },
          { name: "시차를 좁히는 방향", purpose: "시차를 좁히는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "마음이 머무는 곳", purpose: "마음이 머무는 곳과 관련된 흐름과 의미를 보여준다" },
          { name: "그곳에 머무는 이유", purpose: "그곳에 머무는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "현실과의 간극", purpose: "현실과의 간극과 관련된 흐름과 의미를 보여준다" },
          { name: "돌아오게 할 계기", purpose: "돌아오게 할 계기와 관련된 흐름과 의미를 보여준다" },
          { name: "시차를 좁히는 방향", purpose: "시차를 좁히는 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_soul_card",
    categoryGroup: "special",
    topicName: "소울 카드",
    description: "지금 내 영혼과 맞닿아 있는 카드가 전하는 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "소울 카드", purpose: "소울 카드와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "영혼이 전하는 메시지", purpose: "영혼이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "과거의 나", purpose: "과거의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "영혼이 전하는 메시지", purpose: "영혼이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_destiny_card",
    categoryGroup: "special",
    topicName: "운명의 카드",
    description: "오늘 나를 찾아온 카드가 전하는 운명적 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "운명의 카드", purpose: "운명의 카드와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 상황", purpose: "지금의 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "운명이 전하는 메시지", purpose: "운명이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 상황", purpose: "지금의 상황과 관련된 흐름과 의미를 보여준다" },
          { name: "과거의 흐름", purpose: "과거의 흐름과 관련된 흐름과 의미를 보여준다" },
          { name: "운명이 전하는 메시지", purpose: "운명이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_dawn_tarot",
    categoryGroup: "special",
    topicName: "새벽 타로",
    description: "가장 조용한 새벽 시간, 지금 나에게 필요한 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "새벽의 메시지", purpose: "새벽의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 마음", purpose: "지금의 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "새벽이 전하는 메시지", purpose: "새벽이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 마음", purpose: "지금의 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "잠들지 못하는 이유", purpose: "잠들지 못하는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "새벽이 전하는 메시지", purpose: "새벽이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 것", purpose: "필요한 것과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_full_moon_tarot",
    categoryGroup: "special",
    topicName: "보름달 타로",
    description: "달이 가장 밝은 밤, 지금 나에게 드러나는 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "보름달의 메시지", purpose: "보름달의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "보름달이 비추는 것", purpose: "보름달이 비추는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "감춰졌던 것", purpose: "감춰졌던 것과 관련된 흐름과 의미를 보여준다" },
          { name: "보름달이 비추는 메시지", purpose: "보름달이 비추는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_wish_tarot",
    categoryGroup: "special",
    topicName: "소원 타로",
    description: "마음속 소원이 이루어질 수 있는지 확인",
    questionType: "yes_no",
    allowedSpreads: ["one_card", "three_card", "five_card", "yes_no"],
    yesNoEnabled: true,
    isChoiceAb: false,
    promptDomain: "tarot_yesno",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "소원의 가능성", purpose: "소원의 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "소원을 품은 마음", purpose: "소원을 품은 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "이루어지는 데 필요한 것", purpose: "이루어지는 데 필요한 것과 관련된 흐름과 의미를 보여준다" },
          { name: "소원의 실현 가능성", purpose: "소원의 실현 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "소원을 품은 마음", purpose: "소원을 품은 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "소원을 막는 것", purpose: "소원을 막는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "도움이 될 힘", purpose: "도움이 될 힘과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 노력", purpose: "필요한 노력과 관련된 흐름과 의미를 보여준다" },
          { name: "소원의 실현 가능성", purpose: "소원의 실현 가능성과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "yes_no",
        positions: [
          { name: "소원 타로 여부", purpose: "소원 타로가 이루어질지 여부를 카드의 정/역방향으로 명확히 가리킨다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_lucky_door_tarot",
    categoryGroup: "special",
    topicName: "행운의 문 타로",
    description: "지금 열리려는 문 너머에 있는 행운의 기운을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "문 너머의 기운", purpose: "문 너머의 기운과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금 서있는 문", purpose: "지금 서있는 문과 관련된 흐름과 의미를 보여준다" },
          { name: "문 너머의 기운", purpose: "문 너머의 기운과 관련된 흐름과 의미를 보여준다" },
          { name: "문을 여는 방법", purpose: "문을 여는 방법과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금 서있는 문", purpose: "지금 서있는 문과 관련된 흐름과 의미를 보여준다" },
          { name: "문이 열리는 이유", purpose: "문이 열리는 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "문 너머의 기운", purpose: "문 너머의 기운과 관련된 흐름과 의미를 보여준다" },
          { name: "문을 여는 데 필요한 것", purpose: "문을 여는 데 필요한 것과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_maze_of_fate_tarot",
    categoryGroup: "special",
    topicName: "인연의 미로 타로",
    description: "얽힌 인연의 미로 속에서 길을 찾는 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "미로 속 신호", purpose: "미로 속 신호와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "미로에 들어선 이유", purpose: "미로에 들어선 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "지금 서있는 지점", purpose: "지금 서있는 지점과 관련된 흐름과 의미를 보여준다" },
          { name: "미로를 빠져나갈 방향", purpose: "미로를 빠져나갈 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "미로에 들어선 이유", purpose: "미로에 들어선 이유와 관련된 흐름과 의미를 보여준다" },
          { name: "지금 서있는 지점", purpose: "지금 서있는 지점과 관련된 흐름과 의미를 보여준다" },
          { name: "길을 막는 것", purpose: "길을 막는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "빠져나갈 실마리", purpose: "빠져나갈 실마리와 관련된 흐름과 의미를 보여준다" },
          { name: "미로를 빠져나갈 방향", purpose: "미로를 빠져나갈 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_secret_garden_tarot",
    categoryGroup: "special",
    topicName: "비밀 정원 타로",
    description: "숨겨진 정원, 내면 깊은 곳에서 듣는 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "정원의 메시지", purpose: "정원의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "정원으로 들어가는 마음", purpose: "정원으로 들어가는 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "정원이 전하는 메시지", purpose: "정원이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "정원으로 들어가는 마음", purpose: "정원으로 들어가는 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "감춰둔 것", purpose: "감춰둔 것과 관련된 흐름과 의미를 보여준다" },
          { name: "정원이 전하는 메시지", purpose: "정원이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_guardian_star_tarot",
    categoryGroup: "special",
    topicName: "별자리 수호 타로",
    description: "나를 지키는 별이 전하는 수호의 메시지를 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "수호의 메시지", purpose: "수호의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "별이 전하는 메시지", purpose: "별이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "지금의 나", purpose: "지금의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "나를 지켜온 것", purpose: "나를 지켜온 것과 관련된 흐름과 의미를 보여준다" },
          { name: "별이 전하는 메시지", purpose: "별이 전하는 메시지와 관련된 흐름과 의미를 보여준다" },
          { name: "주의할 점", purpose: "주의할 점과 관련된 흐름과 의미를 보여준다" },
          { name: "앞으로의 방향", purpose: "앞으로의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
  {
    topicKey: "special_midnight_vow_tarot",
    categoryGroup: "special",
    topicName: "자정의 서약 타로",
    description: "하루의 끝, 스스로에게 하는 다짐과 그 방향을 확인",
    questionType: "open",
    allowedSpreads: ["one_card", "three_card", "five_card"],
    yesNoEnabled: false,
    isChoiceAb: false,
    promptDomain: "tarot",
    spreads: [
      {
        spreadType: "one_card",
        positions: [
          { name: "서약의 메시지", purpose: "서약의 메시지와 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "three_card",
        positions: [
          { name: "오늘 하루의 나", purpose: "오늘 하루의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "스스로에게 묻는 것", purpose: "스스로에게 묻는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "서약의 방향", purpose: "서약의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
      {
        spreadType: "five_card",
        positions: [
          { name: "오늘 하루의 나", purpose: "오늘 하루의 나와 관련된 흐름과 의미를 보여준다" },
          { name: "남겨진 마음", purpose: "남겨진 마음과 관련된 흐름과 의미를 보여준다" },
          { name: "스스로에게 묻는 것", purpose: "스스로에게 묻는 것과 관련된 흐름과 의미를 보여준다" },
          { name: "필요한 다짐", purpose: "필요한 다짐과 관련된 흐름과 의미를 보여준다" },
          { name: "서약의 방향", purpose: "서약의 방향과 관련된 흐름과 의미를 보여준다" },
        ],
      },
    ],
  },
];

async function main() {
  console.log("[seed_tarot_remaining_60_topics] 시작...");

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
        updatedBy: "system_seed_tarot_remaining_60_topics",
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
        createdBy: "system_seed_tarot_remaining_60_topics",
        updatedBy: "system_seed_tarot_remaining_60_topics",
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
    console.log(`[seed_tarot_remaining_60_topics] "${t.topicName}"(${t.topicKey}) 완료`);
  }

  const topicCount = await prisma.tarotTopic.count();
  const positionCount = await prisma.tarotPosition.count();
  console.log(`[seed_tarot_remaining_60_topics] 완료. tarot_topics=${topicCount}, tarot_positions=${positionCount}`);
}

main()
  .catch((e) => {
    console.error("[seed_tarot_remaining_60_topics] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
