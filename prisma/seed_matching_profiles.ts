// 04A M-1 matching_profiles 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 1차 소단위(매칭 프로필 모니터링).
// UQ(user_id) 제약이므로 회원 10명 중 일부만 매칭 프로필을 등록한 것으로 시딩한다
// (모든 회원이 매칭 기능을 사용하지는 않는 것이 자연스러운 도메인 특성).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ orderBy: { id: "asc" } });

  if (users.length < 7) {
    console.error("회원 데이터가 부족합니다(최소 7명 필요). 선행 시드를 먼저 실행하세요.");
    process.exit(1);
  }

  const profiles = [
    {
      userId: users[0].id,
      isPublic: true,
      preferences: JSON.stringify({ ageRange: [25, 35], gender: "female", region: "seoul" }),
      introText: "사주 공부하며 좋은 인연을 찾고 있어요.",
      status: "active",
    },
    {
      userId: users[1].id,
      isPublic: true,
      preferences: JSON.stringify({ ageRange: [28, 40], gender: "male", region: "busan" }),
      introText: "타로카드 좋아하는 사람이면 좋겠어요.",
      status: "active",
    },
    {
      userId: users[2].id,
      isPublic: false, // 회원이 스스로 비공개 설정(관리자 조치와 무관)
      preferences: JSON.stringify({ ageRange: [20, 30], gender: "unspecified" }),
      introText: null,
      status: "active",
    },
    {
      userId: users[3].id,
      isPublic: true,
      preferences: JSON.stringify({ ageRange: [30, 45], gender: "female", region: "incheon" }),
      introText: "진지한 만남을 원합니다.",
      status: "active",
    },
    {
      userId: users[4].id,
      isPublic: true,
      preferences: null, // 이상형 조건 미입력(선택 항목)
      introText: "안녕하세요!",
      status: "active",
    },
    {
      userId: users[5].id,
      isPublic: true,
      preferences: JSON.stringify({ ageRange: [25, 35], gender: "male" }),
      introText: "부적절한 홍보성 소개글이 포함되어 신고가 누적된 프로필(관리자 비활성화 처리됨).",
      status: "deactivated_by_admin",
    },
    {
      userId: users[6].id,
      isPublic: true,
      preferences: JSON.stringify({ ageRange: [22, 32], gender: "female", region: "daegu" }),
      introText: "여행 좋아하는 분과 인연이 되었으면 합니다.",
      status: "active",
    },
  ];

  for (const p of profiles) {
    await prisma.matchingProfile.create({
      data: {
        userId: p.userId,
        isPublic: p.isPublic,
        preferences: p.preferences,
        introText: p.introText,
        status: p.status,
        deletedAt: null,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`MatchingProfiles created: ${profiles.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
