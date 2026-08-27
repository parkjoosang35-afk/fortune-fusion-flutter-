// [귀인지도(Guinji Map) Phase B-1 — PointPolicy 신규 등록]
//
// 신통방통_귀인지도_최종_개발계획서_v2.0.md §2 R5 / §6 API계약 기준 지급 규칙을
// PointPolicy 2종으로 등록한다(절대원칙: 모든 지급은 PointPolicy 등록).
//
// - guinji_join: 지인이 지도에 합류(GuinjiMapMember 생성)했을 때 "지도 소유자"에게
//   지급되는 보상. §2 R5 "지인 참여 +20P" 그대로 반영. amount=20,
//   dailyLimit=null(건당 1회는 PointHistory.sourceType='guinji_join' +
//   sourceId=GuinjiMapMember.id 조합의 멱등 검사로 별도 강제 — M12).
// - guinji_unlock_special: 스페셜 해설 해금 시 차감되는 포인트(광고 시청 시에는
//   차감 없음, method='point'일 때만 적용). §8 상세화면 명세 "50P" 그대로 반영.
//   amount=50(차감), dailyLimit=5(§7/M12 "일 5회 한도" — GuinjiUnlockRecord.
//   dateKey 집계로 실제 카운트 강제, 이 값은 정책표상 참고/문서화 목적).
//
// [실행] npx tsx prisma/seed_guinji_point_policies.ts
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
  { sourceType: "guinji_join", amount: 20, dailyLimit: null, isActive: true },
  { sourceType: "guinji_unlock_special", amount: 50, dailyLimit: 5, isActive: true },
];

async function main() {
  console.log("=== [귀인지도 Phase B-1] PointPolicy 시딩 시작 ===");
  let created = 0;
  let skipped = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_guinji", updatedBy: "system_seed_guinji" },
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
