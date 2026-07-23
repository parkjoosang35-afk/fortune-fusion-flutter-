// 05_Admin_System_Design.md §3.9 "알림 관리" — 2차 소단위: 발송 이력 조회
// 04A N-2 notifications 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const existing = await prisma.notification.count();
  if (existing > 0) {
    console.log(`이미 ${existing}건의 알림 발송 이력이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const users = await prisma.user.findMany({ take: 5, select: { id: true } });
  if (users.length === 0) {
    throw new Error("시딩할 User가 없습니다. users 테이블을 먼저 채워주세요.");
  }

  const templates = await prisma.notificationTemplate.findMany({
    where: { deletedAt: null },
  });
  const byCode = (code: string) => templates.find((t) => t.code === code) ?? null;

  const now = new Date();
  const hoursAgo = (h: number) => new Date(now.getTime() - h * 60 * 60 * 1000);

  const fortuneTpl = byCode("fortune_ready");
  const likeTpl = byCode("matching_new_like");
  const pointTpl = byCode("point_daily_reward");
  const rouletteTpl = byCode("event_roulette_open");
  const marketingTpl = byCode("marketing_general");

  const data = [
    {
      userId: users[0].id,
      templateId: fortuneTpl?.id ?? null,
      title: fortuneTpl?.title ?? "오늘의 운세가 도착했어요",
      body: fortuneTpl?.body ?? "회원님의 오늘 운세 리포트가 준비되었습니다.",
      isRead: true,
      sentAt: hoursAgo(48),
    },
    {
      userId: users[0].id,
      templateId: pointTpl?.id ?? null,
      title: pointTpl?.title ?? "출석 포인트가 지급되었습니다",
      body: pointTpl?.body ?? "오늘도 출석해주셔서 감사합니다.",
      isRead: true,
      sentAt: hoursAgo(24),
    },
    {
      userId: users[1].id,
      templateId: likeTpl?.id ?? null,
      title: likeTpl?.title ?? "새로운 호감 표시가 있어요",
      body: likeTpl?.body ?? "누군가 회원님에게 호감을 표시했습니다.",
      isRead: false,
      sentAt: hoursAgo(6),
    },
    {
      userId: users[2].id,
      templateId: rouletteTpl?.id ?? null,
      title: rouletteTpl?.title ?? "행운의 룰렛 이벤트 오픈!",
      body: rouletteTpl?.body ?? "지금 룰렛을 돌려보세요.",
      isRead: false,
      sentAt: hoursAgo(3),
    },
    {
      userId: users[3].id,
      templateId: marketingTpl?.id ?? null,
      title: marketingTpl?.title ?? "특별 프로모션 안내",
      body: marketingTpl?.body ?? "회원님만을 위한 특별한 혜택.",
      isRead: false,
      sentAt: hoursAgo(1),
    },
    {
      userId: users[4].id,
      templateId: fortuneTpl?.id ?? null,
      title: fortuneTpl?.title ?? "오늘의 운세가 도착했어요",
      body: fortuneTpl?.body ?? "회원님의 오늘 운세 리포트가 준비되었습니다.",
      isRead: true,
      sentAt: hoursAgo(72),
    },
    {
      userId: users[1].id,
      templateId: pointTpl?.id ?? null,
      title: pointTpl?.title ?? "출석 포인트가 지급되었습니다",
      body: pointTpl?.body ?? "오늘도 출석해주셔서 감사합니다.",
      isRead: false,
      sentAt: hoursAgo(0.5),
    },
    {
      // template_id가 없는 경우(템플릿 없이 발송된 알림) — 04A N-2 명시: template_id는 nullable
      userId: users[2].id,
      templateId: null,
      title: "긴급 공지: 서버 점검 안내",
      body: "오늘 새벽 2시~4시 서버 점검이 진행됩니다.",
      isRead: false,
      sentAt: hoursAgo(12),
    },
  ];

  await prisma.notification.createMany({ data });
  console.log(`알림 발송 이력 ${data.length}건 시딩 완료.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
