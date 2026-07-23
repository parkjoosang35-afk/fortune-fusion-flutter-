// 05_Admin_System_Design.md §3.8 "CMS" — 5차(마지막) 소단위: 이벤트 관리
// 04A N-5(events)/N-6(event_participations) 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

async function main() {
  const existing = await prisma.event.count();
  if (existing > 0) {
    console.log(`이미 ${existing}건의 이벤트가 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const users = await prisma.user.findMany({ take: 5, select: { id: true } });
  if (users.length === 0) {
    throw new Error("시딩할 User가 없습니다. users 테이블을 먼저 채워주세요.");
  }

  const now = new Date();
  const past = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const future = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

  const attendance = await prisma.event.create({
    data: {
      title: "9월 출석 보너스 이벤트",
      imageUrl: null,
      eventType: "attendance_bonus",
      config: JSON.stringify({ daily_reward_point: 50, consecutive_bonus: { 7: 500, 30: 3000 } }),
      startAt: past,
      endAt: future,
      isActive: true,
    },
  });

  const roulette = await prisma.event.create({
    data: {
      title: "가을맞이 행운의 룰렛",
      imageUrl: "https://example.com/events/roulette.png",
      eventType: "roulette",
      config: JSON.stringify({
        segments: [
          { label: "100포인트", weight: 40, reward_point: 100 },
          { label: "500포인트", weight: 20, reward_point: 500 },
          { label: "무료운세권", weight: 10, reward_type: "free_fortune" },
          { label: "꽝", weight: 30, reward_point: 0 },
        ],
        daily_spin_limit: 1,
      }),
      startAt: now,
      endAt: future,
      isActive: true,
    },
  });

  const special = await prisma.event.create({
    data: {
      title: "추석 특별 미션 이벤트",
      imageUrl: null,
      eventType: "special_mission",
      config: JSON.stringify({
        missions: [
          { id: "share_app", title: "앱 공유하기", reward_point: 200 },
          { id: "invite_friend", title: "친구 초대하기", reward_point: 500 },
        ],
      }),
      startAt: past,
      endAt: past,
      isActive: false,
    },
  });

  await prisma.eventParticipation.createMany({
    data: [
      { eventId: attendance.id, userId: users[0].id, participationData: JSON.stringify({ streak: 5 }), rewardClaimed: true },
      { eventId: attendance.id, userId: users[1].id, participationData: JSON.stringify({ streak: 2 }), rewardClaimed: false },
      { eventId: roulette.id, userId: users[0].id, participationData: JSON.stringify({ spins_used: 1, result: "100포인트" }), rewardClaimed: true },
      { eventId: roulette.id, userId: users[2].id, participationData: JSON.stringify({ spins_used: 1, result: "꽝" }), rewardClaimed: false },
      { eventId: roulette.id, userId: users[3].id, participationData: JSON.stringify({ spins_used: 1, result: "무료운세권" }), rewardClaimed: true },
      { eventId: special.id, userId: users[4].id, participationData: JSON.stringify({ missions_done: ["share_app"] }), rewardClaimed: false },
    ],
  });

  console.log("이벤트 3건, 참여기록 6건 시딩 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
