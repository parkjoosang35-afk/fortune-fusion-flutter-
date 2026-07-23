// 04A L-4 comments(폴리모픽) 시드 데이터
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 2차 소단위(댓글 관리).
// target_type=post/wish 각각에 댓글을 생성하여 폴리모픽 목록/삭제 화면을 검증한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ take: 6, orderBy: { id: "asc" } });
  if (users.length === 0) {
    console.error("시드할 회원이 없습니다. 회원 시드를 먼저 실행하세요.");
    process.exit(1);
  }

  const posts = await prisma.communityPost.findMany({
    where: { status: "visible" },
    orderBy: { id: "asc" },
    take: 3,
  });
  const wishes = await prisma.wish.findMany({
    where: { status: "visible" },
    orderBy: { id: "asc" },
    take: 2,
  });
  if (posts.length === 0 || wishes.length === 0) {
    console.error("댓글을 달 게시글/소원이 없습니다. seed_community.ts를 먼저 실행하세요.");
    process.exit(1);
  }

  // target_type=post 댓글 5건(active 4 + deleted_by_admin 1)
  const postComments = [
    { targetId: posts[0].id, userId: users[1].id, content: "좋은 글 감사합니다!", status: "active" },
    { targetId: posts[0].id, userId: users[2].id, content: "저도 공감해요.", status: "active" },
    { targetId: posts[1].id, userId: users[0].id, content: "저는 산책을 추천드려요.", status: "active" },
    { targetId: posts[2].id, userId: users[3].id, content: "궁금했던 내용인데 잘 봤습니다.", status: "active" },
    { targetId: posts[0].id, userId: users[4].id, content: "부적절한 광고성 댓글입니다.", status: "deleted_by_admin" },
  ];

  for (const c of postComments) {
    await prisma.comment.create({
      data: {
        targetType: "post",
        targetId: c.targetId,
        userId: c.userId,
        content: c.content,
        status: c.status,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Comments(post) created: ${postComments.length}건`);

  // target_type=wish 댓글 3건(active 2 + deleted_by_admin 1)
  const wishComments = [
    { targetId: wishes[0].id, userId: users[5].id, content: "응원합니다! 꼭 이루어지길 바라요.", status: "active" },
    { targetId: wishes[1].id, userId: users[2].id, content: "저도 같은 마음입니다.", status: "active" },
    { targetId: wishes[0].id, userId: users[3].id, content: "부적절한 내용의 댓글(신고 처리됨)", status: "deleted_by_admin" },
  ];

  for (const c of wishComments) {
    await prisma.comment.create({
      data: {
        targetType: "wish",
        targetId: c.targetId,
        userId: c.userId,
        content: c.content,
        status: c.status,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Comments(wish) created: ${wishComments.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
