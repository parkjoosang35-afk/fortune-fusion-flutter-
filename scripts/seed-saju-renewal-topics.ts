// [정통사주 리뉴얼 v1.0] topic_catalog 시드 스크립트 (29종).
//
// 기존 prisma/seed.ts(관리자 계정/RBAC)와는 별도 책임이므로 독립 스크립트로 둔다
// (기존 seed.ts 무변경 원칙 — "기존 테이블/시드 로직 건드리지 않는다").
//
// 실행: npx tsx scripts/seed-saju-renewal-topics.ts
//
// [동점 처리 규칙] TOPIC_CATALOG_SEED 배열의 선언 순서(=지시서 §7 표 순서)를
// 그대로 sortOrder로 매핑한다. topic-engine.ts는 점수 동점 시 sortOrder 오름차순,
// 그래도 같으면 topicId 사전순으로 정렬한다(디자인팀 승인조건① 그대로 구현).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import { TOPIC_CATALOG_SEED } from "../src/lib/saju-renewal/topic-catalog-data";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log(`[seed-saju-renewal-topics] topic_catalog ${TOPIC_CATALOG_SEED.length}종 시딩...`);

  let created = 0;
  let updated = 0;

  for (let i = 0; i < TOPIC_CATALOG_SEED.length; i++) {
    const item = TOPIC_CATALOG_SEED[i];
    const existing = await prisma.topicCatalog.findUnique({
      where: { topicId: item.topicId },
    });

    await prisma.topicCatalog.upsert({
      where: { topicId: item.topicId },
      update: {
        topicName: item.topicName,
        categoryGroup: item.categoryGroup,
        isTiming: item.isTiming,
        isFallback: item.isFallback,
        releasePhase: item.releasePhase,
        sortOrder: i, // 선언 순서 = 동점 처리 1순위 기준
      },
      create: {
        topicId: item.topicId,
        topicName: item.topicName,
        categoryGroup: item.categoryGroup,
        isTiming: item.isTiming,
        isFallback: item.isFallback,
        releasePhase: item.releasePhase,
        sortOrder: i,
      },
    });

    if (existing) updated++;
    else created++;

    // [TopicCondition 시딩] requiredFacts 원문을 "필요 근거 설명" 조건 1건으로
    // 보관한다. 지시서는 이 키를 saju_v3 facts의 실제 필드명으로 매핑하는
    // 세부 판정식을 아직 확정하지 않았으므로(§필터 "충족 근거 ≥2"만 확정),
    // 이 단계에서는 "참고용 설명 텍스트"로만 저장하고, 실제 판정 로직은
    // topic-engine.ts가 운영 중 조정 가능하게 별도 관리한다.
    const conditionType = "required_facts_description";
    const existingCondition = await prisma.topicCondition.findFirst({
      where: { topicId: item.topicId, conditionType },
    });
    if (!existingCondition) {
      await prisma.topicCondition.create({
        data: {
          topicId: item.topicId,
          conditionType,
          conditionValue: JSON.stringify({
            text: item.requiredFacts,
            note: item.note,
          }),
        },
      });
    } else {
      await prisma.topicCondition.update({
        where: { id: existingCondition.id },
        data: {
          conditionValue: JSON.stringify({
            text: item.requiredFacts,
            note: item.note,
          }),
        },
      });
    }
  }

  console.log(
    `[seed-saju-renewal-topics] 완료 — 생성 ${created}건 / 갱신 ${updated}건 (총 ${TOPIC_CATALOG_SEED.length}종)`
  );

  const timingCount = TOPIC_CATALOG_SEED.filter((t) => t.isTiming).length;
  const phase1Count = TOPIC_CATALOG_SEED.filter((t) => t.releasePhase === 1).length;
  const phase2Count = TOPIC_CATALOG_SEED.filter((t) => t.releasePhase === 2).length;
  console.log(
    `[seed-saju-renewal-topics] 검증 — 시기형 ${timingCount}종 · 1차릴리즈 ${phase1Count}종 · 2차릴리즈 ${phase2Count}종`
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
