// [복주머니 확장 항목3 — 감사 도장(GratitudeSeal) PointPolicy 신규 등록]
//
// bokjumeoni-plan(01-planning.html §07 "벗의 감사 도장" / 03-dev-spec.html
// §"감사 도장 · Gratitude" API 표)의 지급 규칙:
//   "받은 사람은 +5 복, 찍은 사람은 +2 복"
// 을 PointPolicy 2종으로 등록한다(절대원칙: 모든 지급은 PointPolicy 등록).
//
// - gratitude_seal_sender: 도장을 "찍는" 사람(=원래 sendPouch를 받은 사람)에게
//   지급되는 답례 보상. amount=2, dailyLimit=null(건당 1회는 GratitudeSeal.
//   sourcePouchId unique 제약 + PointHistory sourceId 중복 검사로 별도 강제).
// - gratitude_seal_recipient: 도장을 "받는" 사람(=원래 sendPouch를 보낸 사람)에게
//   지급되는 감사 보상. amount=5, dailyLimit=null(동일하게 sourceId 기반 건당
//   1회 제한).
//
// [실행] npx tsx prisma/seed_gratitude_seal_phase.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const POLICIES: Array<{
  sourceType: string;
  amount: number;
  dailyLimit: number | null;
  isActive: boolean;
}> = [
  { sourceType: "gratitude_seal_sender", amount: 2, dailyLimit: null, isActive: true },
  { sourceType: "gratitude_seal_recipient", amount: 5, dailyLimit: null, isActive: true },
];

async function main() {
  console.log("=== [항목3] 감사 도장 PointPolicy 시딩 시작 ===");
  let created = 0;
  let skipped = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_gratitude", updatedBy: "system_seed_gratitude" },
    });
    created++;
  }
  console.log(`=== 완료: ${created}건 생성, ${skipped}건 기존 skip ===`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
