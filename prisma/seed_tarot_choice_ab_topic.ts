// [신통방통 타로 65종 주제 연동 - §계획4 A/B 양자택일 전용 스프레드]
// `daily_direction_of_choice`(선택의 방향, category.id 기준)는 대표님
// 마스터 프롬프트 §18 "A/B 양자택일은 YES/NO와 별도 처리" 원칙에 따라
// 카드 수/포지션 구조가 다른 64개 주제와 완전히 다르다(A선택지+B선택지
// 각각 별도 추첨). docs/tarot_65_topics_design_table.md §43 확정 문구를
// 그대로 반영해, 신규 스프레드 타입 `choice_ab` 1종만 시딩한다(1/3/5카드/
// yes_no는 이 주제에서 지원하지 않음 - allowedSpreads에 choice_ab만 포함).
//
// 포지션 5개(설계표 §43 5카드 문구 그대로):
//   ①선택 A 현재 ②선택 A 결과 흐름 ③선택 B 현재 ④선택 B 결과 흐름
//   ⑤최종 조언(두 선택 비교)
// route.ts의 choice_ab 처리 로직은 이 5개 포지션 중 앞 2개를 선택지A 추첨
// 결과, 다음 2개를 선택지B 추첨 결과, 마지막 1개를 종합조언 카드로 사용한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const TOPIC_KEY = "daily_direction_of_choice";

const POSITIONS: { name: string; purpose: string }[] = [
  { name: "선택 A 현재", purpose: "선택지 A를 골랐을 때 지금 시점에서 놓인 상황과 기운을 보여준다" },
  { name: "선택 A 결과 흐름", purpose: "선택지 A를 선택했을 때 앞으로 이어질 결과와 흐름을 보여준다" },
  { name: "선택 B 현재", purpose: "선택지 B를 골랐을 때 지금 시점에서 놓인 상황과 기운을 보여준다" },
  { name: "선택 B 결과 흐름", purpose: "선택지 B를 선택했을 때 앞으로 이어질 결과와 흐름을 보여준다" },
  { name: "최종 조언", purpose: "두 선택지의 결과를 비교해 어느 쪽이 더 나은지, 무엇을 더 고려해야 하는지 종합 조언을 준다" },
];

async function main() {
  console.log("[seed_tarot_choice_ab_topic] 시작...");

  const topic = await prisma.tarotTopic.upsert({
    where: { topicKey: TOPIC_KEY },
    update: {
      categoryGroup: "daily",
      topicName: "선택의 방향",
      description:
        "두 갈래 선택지 중 어느 쪽이 더 나에게 맞는지, 각 선택의 결과를 비교해 확인하는 A/B 양자택일 전용 주제",
      questionType: "choice_ab",
      allowedSpreads: JSON.stringify(["choice_ab"]),
      yesNoEnabled: false,
      isChoiceAb: true,
      promptDomain: "tarot",
      updatedBy: "system_seed_tarot_choice_ab_topic",
    },
    create: {
      topicKey: TOPIC_KEY,
      categoryGroup: "daily",
      topicName: "선택의 방향",
      description:
        "두 갈래 선택지 중 어느 쪽이 더 나에게 맞는지, 각 선택의 결과를 비교해 확인하는 A/B 양자택일 전용 주제",
      questionType: "choice_ab",
      allowedSpreads: JSON.stringify(["choice_ab"]),
      yesNoEnabled: false,
      isChoiceAb: true,
      promptDomain: "tarot",
      createdBy: "system_seed_tarot_choice_ab_topic",
      updatedBy: "system_seed_tarot_choice_ab_topic",
    },
  });

  for (let i = 0; i < POSITIONS.length; i++) {
    const pos = POSITIONS[i];
    await prisma.tarotPosition.upsert({
      where: {
        topicId_spreadType_positionIndex: {
          topicId: topic.id,
          spreadType: "choice_ab",
          positionIndex: i,
        },
      },
      update: {
        positionName: pos.name,
        positionPurpose: pos.purpose,
      },
      create: {
        topicId: topic.id,
        spreadType: "choice_ab",
        positionIndex: i,
        positionName: pos.name,
        positionPurpose: pos.purpose,
      },
    });
  }

  console.log(`[seed_tarot_choice_ab_topic] "${topic.topicName}"(${topic.topicKey}) 토픽 + choice_ab 5포지션 완료`);

  const topicCount = await prisma.tarotTopic.count();
  const positionCount = await prisma.tarotPosition.count();
  console.log(`[seed_tarot_choice_ab_topic] 완료. tarot_topics=${topicCount}, tarot_positions=${positionCount}`);
}

main()
  .catch((e) => {
    console.error("[seed_tarot_choice_ab_topic] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
