// 04A N-8 popups 시드 데이터
// 05_Admin_System_Design.md §3.8 "CMS" — 2차 소단위(팝업 관리).
// display_condition: {once: boolean, segment?: string} 형태(JSON.stringify)로
// "1회성/반복 설정"(05 화면기능) 및 세그먼트 조건을 표현.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}
function daysAgo(days: number): Date {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

async function main() {
  const popupsData = [
    {
      title: "신규 가입 이벤트 안내",
      imageUrl: "https://picsum.photos/seed/popup1/600/800",
      linkUrl: "https://example.com/events/welcome",
      displayCondition: JSON.stringify({ once: true, segment: "new_user" }),
      startAt: daysAgo(3),
      endAt: daysFromNow(7),
      isActive: true,
    },
    {
      title: "설 연휴 운영시간 안내",
      imageUrl: null,
      linkUrl: null,
      displayCondition: JSON.stringify({ once: false }),
      startAt: daysAgo(1),
      endAt: daysFromNow(3),
      isActive: true,
    },
    {
      title: "프리미엄 구독 프로모션",
      imageUrl: "https://picsum.photos/seed/popup3/600/800",
      linkUrl: "https://example.com/promo/premium",
      displayCondition: JSON.stringify({ once: true, segment: "free_user" }),
      startAt: daysAgo(10),
      endAt: daysFromNow(20),
      isActive: true,
    },
    {
      title: "(종료) 여름 이벤트 팝업",
      imageUrl: "https://picsum.photos/seed/popup4/600/800",
      linkUrl: "https://example.com/events/summer",
      displayCondition: JSON.stringify({ once: false }),
      startAt: daysAgo(60),
      endAt: daysAgo(30),
      isActive: false,
    },
  ];

  for (const p of popupsData) {
    await prisma.popup.create({
      data: { ...p, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`Popups created: ${popupsData.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
