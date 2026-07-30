// 소원성(Wish Castle) 관리자 설정 초기 시딩 스크립트.
// wish_config 테이블에 촛불 레벨 임계값/보상/문구/애니메이션 ON-OFF 기본값을 upsert한다.
// economy_config 시딩 패턴(직접 upsert, wish-config-meta.ts 화이트리스트 재사용)과 동일.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import { WISH_CONFIG_KEYS } from "../src/lib/wish-config-meta";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log("[seed_wish_castle] wish_config 기본값 시딩...");
  for (const meta of WISH_CONFIG_KEYS) {
    await prisma.wishConfig.upsert({
      where: { key: meta.key },
      update: {}, // 이미 존재하면 값 덮어쓰지 않음(관리자가 수정한 값 보존)
      create: {
        key: meta.key,
        value: meta.defaultValue,
        description: meta.description,
        updatedBy: "system_seed",
      },
    });
  }
  console.log(`[seed_wish_castle]    -> ${WISH_CONFIG_KEYS.length}개 설정 완료`);
}

main()
  .catch((e) => {
    console.error("[seed_wish_castle] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
