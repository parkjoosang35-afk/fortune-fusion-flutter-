// 04A L-1/L-2/L-3 커뮤니티(community_boards/community_posts/wishes) 시드 데이터
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 1차 소단위.
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

  // ── 04A L-1 community_boards: 3건 (자유/사주공유/타로공유) ──
  const free = await prisma.communityBoard.create({
    data: {
      code: "free",
      name: "자유게시판",
      description: "자유롭게 이야기를 나누는 공간입니다.",
      sortOrder: 1,
      isPublic: true,
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const sajuShare = await prisma.communityBoard.create({
    data: {
      code: "saju_share",
      name: "사주 공유",
      description: "나의 사주 풀이 결과를 공유해보세요.",
      sortOrder: 2,
      isPublic: true,
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const tarotShare = await prisma.communityBoard.create({
    data: {
      code: "tarot_share",
      name: "타로 공유",
      description: "타로 카드 결과와 해석을 나눠보세요.",
      sortOrder: 3,
      isPublic: false, // 비공개 게시판 케이스(공개설정 UI 확인용)
      createdBy: "system",
      updatedBy: "system",
    },
  });

  console.log("CommunityBoards created:", free.code, sajuShare.code, tarotShare.code);

  // ── 04A L-2 community_posts: 8건 (정상 6 + 관리자 숨김 1 + 관리자 삭제 1) ──
  const postsData = [
    { boardId: free.id, userId: users[0].id, title: "오늘 하루 감사한 일", content: "작은 것에도 감사하며 살아가려 합니다.", status: "visible", isPinned: true },
    { boardId: free.id, userId: users[1].id, title: "다들 어떻게 지내세요?", content: "요즘 날씨가 좋네요. 다들 잘 지내시나요?", status: "visible", isPinned: false },
    { boardId: free.id, userId: users[2].id, title: "취미 추천해주세요", content: "새로운 취미를 찾고 있는데 추천 부탁드려요.", status: "visible", isPinned: false },
    { boardId: sajuShare.id, userId: users[0].id, title: "사주에서 재물운이 좋다고 나왔어요", content: "이번 달 사주풀이 결과를 공유합니다.", status: "visible", isPinned: false },
    { boardId: sajuShare.id, userId: users[3].id, title: "궁금한 점이 있어요", content: "사주에서 이런 표현이 나왔는데 무슨 뜻인가요?", status: "visible", isPinned: false },
    { boardId: tarotShare.id, userId: users[1].id, title: "오늘의 타로, 별카드가 나왔어요", content: "희망적인 메시지를 받은 것 같아 기분이 좋습니다.", status: "visible", isPinned: false },
    { boardId: free.id, userId: users[4].id, title: "광고성 홍보글입니다", content: "이 링크를 눌러서 확인해보세요! (스팸 의심)", status: "blinded", isPinned: false },
    { boardId: free.id, userId: users[5].id, title: "부적절한 내용의 게시글", content: "신고 누적으로 관리자에 의해 삭제된 게시글입니다.", status: "deleted_by_admin", isPinned: false },
  ];

  for (const p of postsData) {
    await prisma.communityPost.create({
      data: {
        boardId: p.boardId,
        userId: p.userId,
        title: p.title,
        content: p.content,
        status: p.status,
        isPinned: p.isPinned,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`CommunityPosts created: ${postsData.length}건`);

  // ── 04A L-3 wishes: 6건 (정상 5 + 관리자 숨김 1) ──
  const wishesData = [
    { userId: users[0].id, content: "올해는 건강하게 지낼 수 있기를 바랍니다.", category: "health", isAnonymous: false, status: "visible" },
    { userId: users[1].id, content: "취업이 잘 되기를 소망합니다.", category: "wealth", isAnonymous: true, status: "visible" },
    { userId: users[2].id, content: "좋은 인연을 만나고 싶어요.", category: "love", isAnonymous: false, status: "visible" },
    { userId: users[3].id, content: "시험에 꼭 합격하고 싶습니다.", category: "exam", isAnonymous: false, status: "visible" },
    { userId: users[4].id, content: "가족 모두 건강하고 평안하기를.", category: "health", isAnonymous: true, status: "visible" },
    { userId: users[5].id, content: "부적절한 소원 내용(신고 처리됨)", category: "wealth", isAnonymous: false, status: "blinded" },
  ];

  for (const w of wishesData) {
    await prisma.wish.create({
      data: {
        userId: w.userId,
        content: w.content,
        category: w.category,
        isAnonymous: w.isAnonymous,
        status: w.status,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Wishes created: ${wishesData.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
