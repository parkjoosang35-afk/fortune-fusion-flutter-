// 04A M-4 friends / M-5 follows 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 3차 소단위(친구/팔로우 모니터링,
// "선택, 조회 전용"). friends는 status 3가지(requested/accepted/blocked)를 각각
// 포함하도록, follows는 단순 팔로우 관계 여러 건을 시딩한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ orderBy: { id: "asc" } });
  if (users.length < 10) {
    console.error("회원 데이터가 부족합니다(최소 10명 필요). 선행 시드를 먼저 실행하세요.");
    process.exit(1);
  }
  const u = (i: number) => users[i].id; // 0-indexed 편의 함수

  // ── friends: requested/accepted/blocked 각 상태 포함 8건 ──
  const friends = [
    { userId: u(0), friendUserId: u(1), status: "accepted" }, // 1↔2 친구 성사
    { userId: u(1), friendUserId: u(0), status: "accepted" }, // 대칭 레코드(양방향 표현)
    { userId: u(2), friendUserId: u(3), status: "accepted" }, // 3↔4 친구 성사
    { userId: u(3), friendUserId: u(2), status: "accepted" },
    { userId: u(4), friendUserId: u(5), status: "requested" }, // 5→6 친구 요청 대기중
    { userId: u(6), friendUserId: u(7), status: "requested" }, // 7→8 친구 요청 대기중
    { userId: u(8), friendUserId: u(9), status: "blocked" }, // 9가 10을 차단
    { userId: u(7), friendUserId: u(2), status: "blocked" }, // 8이 3을 차단(신고 연계 시나리오)
  ];
  for (const f of friends) {
    await prisma.friend.create({
      data: { ...f, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`Friends created: ${friends.length}건`);

  // ── follows: 단순 팔로우 관계 9건 (일부 유저는 다수의 팔로워를 보유) ──
  const follows = [
    { followerId: u(1), followingId: u(0), status: "active" },
    { followerId: u(2), followingId: u(0), status: "active" },
    { followerId: u(3), followingId: u(0), status: "active" },
    { followerId: u(4), followingId: u(0), status: "active" }, // 1번 유저는 팔로워 4명(인기 유저 시나리오)
    { followerId: u(0), followingId: u(1), status: "active" }, // 상호 팔로우
    { followerId: u(5), followingId: u(6), status: "active" },
    { followerId: u(6), followingId: u(5), status: "active" }, // 상호 팔로우
    { followerId: u(7), followingId: u(8), status: "active" },
    { followerId: u(9), followingId: u(0), status: "active" },
  ];
  for (const fo of follows) {
    await prisma.follow.create({
      data: { ...fo, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`Follows created: ${follows.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
