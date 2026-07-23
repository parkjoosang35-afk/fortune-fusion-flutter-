// 04A M-2 matching_likes / M-3 matching_pairs 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 2차 소단위(매칭 성사 이력).
// 회원 10명 중 일부 조합으로 매칭 좋아요(단방향)를 만들고, 그중 상호 좋아요가
// 성립된 쌍은 matching_pairs로 이어지도록 시딩한다(어뷰징 탐지 시나리오 포함:
// 한 명이 여러 명에게 좋아요를 남발하는 패턴 1건 포함).
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

  // ── matching_likes: 단방향 좋아요 9건 ──
  const likes = [
    { fromUserId: u(0), toUserId: u(1), type: "normal", status: "active" }, // 1→2 (상호성립 예정)
    { fromUserId: u(1), toUserId: u(0), type: "normal", status: "active" }, // 2→1 (상호성립 예정, pair 1)
    { fromUserId: u(3), toUserId: u(6), type: "super", status: "active" }, // 4→7 (상호성립 예정)
    { fromUserId: u(6), toUserId: u(3), type: "normal", status: "active" }, // 7→4 (상호성립 예정, pair 2)
    { fromUserId: u(2), toUserId: u(4), type: "normal", status: "active" }, // 3→5 (미성립, 편도)
    // 어뷰징 의심 패턴: 8번 유저가 여러 명에게 좋아요 남발
    { fromUserId: u(7), toUserId: u(0), type: "normal", status: "active" },
    { fromUserId: u(7), toUserId: u(1), type: "normal", status: "active" },
    { fromUserId: u(7), toUserId: u(2), type: "normal", status: "active" },
    { fromUserId: u(7), toUserId: u(4), type: "normal", status: "active" },
  ];
  for (const l of likes) {
    await prisma.matchingLike.create({
      data: { ...l, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`MatchingLikes created: ${likes.length}건`);

  // ── matching_pairs: 상호 좋아요가 성립된 2쌍 + 이후 unmatched 처리된 1쌍 ──
  const pairs = [
    { userAId: u(0), userBId: u(1), status: "active" }, // 1↔2 성사
    { userAId: u(3), userBId: u(6), status: "active" }, // 4↔7 성사
    { userAId: u(5), userBId: u(8), status: "unmatched" }, // 과거 성사되었으나 이후 매칭 해제됨
  ];
  for (const p of pairs) {
    await prisma.matchingPair.create({
      data: { ...p, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`MatchingPairs created: ${pairs.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
