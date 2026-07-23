// 05_Admin_System_Design.md §3.9 "알림 관리" — 1차 소단위: 알림 템플릿 관리
// 04A N-1 notification_templates 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const existing = await prisma.notificationTemplate.count();
  if (existing > 0) {
    console.log(`이미 ${existing}건의 알림 템플릿이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const templatesData = [
    {
      code: "fortune_ready",
      title: "오늘의 운세가 도착했어요",
      body: "회원님의 오늘 운세 리포트가 준비되었습니다. 지금 확인해보세요!",
      deepLink: "app://fortune/today",
    },
    {
      code: "matching_new_like",
      title: "새로운 호감 표시가 있어요",
      body: "누군가 회원님에게 호감을 표시했습니다. 지금 확인해보세요!",
      deepLink: "app://matching/likes",
    },
    {
      code: "point_daily_reward",
      title: "출석 포인트가 지급되었습니다",
      body: "오늘도 출석해주셔서 감사합니다. 포인트가 적립되었어요.",
      deepLink: "app://reward/points",
    },
    {
      code: "event_roulette_open",
      title: "행운의 룰렛 이벤트 오픈!",
      body: "지금 룰렛을 돌리고 다양한 포인트 혜택을 받아보세요.",
      deepLink: "app://events/roulette",
    },
    {
      code: "community_comment_reply",
      title: "내 게시글에 댓글이 달렸어요",
      body: "회원님의 게시글에 새로운 댓글이 등록되었습니다.",
      deepLink: "app://community/posts",
    },
    {
      code: "subscription_expiring",
      title: "구독이 곧 만료됩니다",
      body: "구독하신 플랜이 3일 후 만료됩니다. 갱신을 원하시면 확인해보세요.",
      deepLink: "app://payments/subscriptions",
    },
    {
      code: "marketing_general",
      title: "특별 프로모션 안내",
      body: "회원님만을 위한 특별한 혜택이 도착했습니다.",
      deepLink: null,
    },
  ];

  await prisma.notificationTemplate.createMany({ data: templatesData });
  console.log(`알림 템플릿 ${templatesData.length}건 시딩 완료.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
