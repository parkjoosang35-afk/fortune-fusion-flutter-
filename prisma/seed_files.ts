// 04A L-7 files(폴리모픽 공용) 시드 데이터
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 5차(마지막) 소단위(파일/업로드 관리).
// owner_type=user_profile/community_post/amulet_item/banner 각각에 대한 파일을
// 생성하여 폴리모픽 목록/삭제 화면을 검증한다. owner_id가 null인 미연결 파일도
// 1건 포함한다(04A 명시대로 owner_id는 nullable).
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
  const amulets = await prisma.amuletItem.findMany({ orderBy: { id: "asc" } });
  const banners = await prisma.banner.findMany({ orderBy: { id: "asc" } });

  if (users.length < 3 || posts.length === 0 || amulets.length === 0 || banners.length === 0) {
    console.error("파일 대상(회원/게시글/부적/배너)이 부족합니다. 선행 시드를 먼저 실행하세요.");
    process.exit(1);
  }

  const files = [
    // 1) user_profile 프로필 이미지 — active
    {
      ownerType: "user_profile",
      ownerId: users[0].id,
      fileUrl: "https://cdn.example.com/profiles/user1_avatar.jpg",
      fileType: "image",
      size: 245_000,
      status: "active",
    },
    // 2) user_profile 프로필 이미지 — active
    {
      ownerType: "user_profile",
      ownerId: users[1].id,
      fileUrl: "https://cdn.example.com/profiles/user2_avatar.jpg",
      fileType: "image",
      size: 198_000,
      status: "active",
    },
    // 3) community_post 첨부 이미지 — active
    {
      ownerType: "community_post",
      ownerId: posts[0].id,
      fileUrl: "https://cdn.example.com/posts/post1_photo1.jpg",
      fileType: "image",
      size: 1_024_000,
      status: "active",
    },
    // 4) community_post 첨부 이미지 — 문제 이미지(관리자 삭제 처리됨)
    {
      ownerType: "community_post",
      ownerId: posts[0].id,
      fileUrl: "https://cdn.example.com/posts/post1_inappropriate.jpg",
      fileType: "image",
      size: 880_000,
      status: "deleted_by_admin",
    },
    // 5) community_post 첨부 동영상 — active
    {
      ownerType: "community_post",
      ownerId: posts.length > 1 ? posts[1].id : posts[0].id,
      fileUrl: "https://cdn.example.com/posts/post2_clip.mp4",
      fileType: "video",
      size: 15_360_000,
      status: "active",
    },
    // 6) amulet_item 이미지 — active
    {
      ownerType: "amulet_item",
      ownerId: amulets[0].id,
      fileUrl: "https://cdn.example.com/amulets/amulet1.png",
      fileType: "image",
      size: 512_000,
      status: "active",
    },
    // 7) amulet_item 이미지 — active
    {
      ownerType: "amulet_item",
      ownerId: amulets.length > 1 ? amulets[1].id : amulets[0].id,
      fileUrl: "https://cdn.example.com/amulets/amulet2.png",
      fileType: "image",
      size: 498_000,
      status: "active",
    },
    // 8) banner 이미지 — active
    {
      ownerType: "banner",
      ownerId: banners[0].id,
      fileUrl: "https://cdn.example.com/banners/banner1.jpg",
      fileType: "image",
      size: 320_000,
      status: "active",
    },
    // 9) community_post 첨부 이미지 — 저작권 침해로 삭제 처리됨
    {
      ownerType: "community_post",
      ownerId: posts.length > 2 ? posts[2].id : posts[0].id,
      fileUrl: "https://cdn.example.com/posts/post3_copyright_violation.jpg",
      fileType: "image",
      size: 760_000,
      status: "deleted_by_admin",
    },
    // 10) owner 미연결 파일 — 업로드 직후 아직 연결 전(04A 명시대로 owner_id nullable)
    {
      ownerType: "community_post",
      ownerId: null,
      fileUrl: "https://cdn.example.com/uploads/orphan_temp_12345.jpg",
      fileType: "image",
      size: 150_000,
      status: "active",
    },
  ];

  for (const f of files) {
    await prisma.file.create({
      data: {
        ownerType: f.ownerType,
        ownerId: f.ownerId,
        fileUrl: f.fileUrl,
        fileType: f.fileType,
        size: f.size,
        status: f.status,
        deletedAt: f.status === "deleted_by_admin" ? new Date() : null,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Files created: ${files.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
