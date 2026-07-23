// 04A L-5 likes(폴리모픽) 시드 데이터
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 4차 소단위(좋아요 통계).
// target_type=post/wish/comment 각각에 좋아요를 생성하며, 어뷰징 패턴 탐지
// 화면 검증을 위해 특정 대상(posts[0])에 좋아요가 몰리는 시나리오를 포함한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ orderBy: { id: "asc" } });
  const posts = await prisma.communityPost.findMany({ orderBy: { id: "asc" } });
  const wishes = await prisma.wish.findMany({ orderBy: { id: "asc" } });
  const comments = await prisma.comment.findMany({ orderBy: { id: "asc" } });

  if (users.length < 6 || posts.length === 0 || wishes.length === 0 || comments.length === 0) {
    console.error("좋아요를 누를 대상(회원/게시글/소원/댓글)이 부족합니다. 선행 시드를 먼저 실행하세요.");
    process.exit(1);
  }

  const likes: { targetType: string; targetId: number; userId: number }[] = [];

  // 1) posts[0] — 어뷰징 탐지 시나리오: 전체 회원(6명)이 모두 좋아요(집중 몰림)
  for (const u of users) {
    likes.push({ targetType: "post", targetId: posts[0].id, userId: u.id });
  }

  // 2) posts[1] — 일반적인 분산 좋아요(2명)
  likes.push({ targetType: "post", targetId: posts[1].id, userId: users[0].id });
  likes.push({ targetType: "post", targetId: posts[1].id, userId: users[2].id });

  // 3) posts[2] — 좋아요 없음(비교군)

  // 4) wishes — 각 소원에 1~2명
  likes.push({ targetType: "wish", targetId: wishes[0].id, userId: users[1].id });
  likes.push({ targetType: "wish", targetId: wishes[0].id, userId: users[3].id });
  likes.push({ targetType: "wish", targetId: wishes[1].id, userId: users[4].id });

  // 5) comments — 일부 댓글에 좋아요
  likes.push({ targetType: "comment", targetId: comments[0].id, userId: users[2].id });
  likes.push({ targetType: "comment", targetId: comments[0].id, userId: users[5].id });
  likes.push({ targetType: "comment", targetId: comments[2].id, userId: users[1].id });

  for (const l of likes) {
    await prisma.like.create({
      data: {
        targetType: l.targetType,
        targetId: l.targetId,
        userId: l.userId,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Likes created: ${likes.length}건 (post[0]에 ${users.length}건 집중 — 어뷰징 탐지 시나리오)`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
