// 04A L-6 reports(폴리모픽) 시드 데이터
// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 3차 소단위(신고 처리함).
// target_type=post/comment/wish/user 각각에 대한 신고를 생성하여 폴리모픽
// 목록/담당자배정/조치 화면을 검증한다. status 4단계(pending/reviewed/actioned/
// rejected)를 모두 포함하도록 구성한다(schema.prisma 설계 결정 1 참조).
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
  const admin = await prisma.adminUser.findFirst({ orderBy: { id: "asc" } });
  const fortuneResults = await prisma.fortuneResult.findMany({ orderBy: { id: "asc" } });

  if (users.length < 6 || posts.length === 0 || wishes.length === 0 || comments.length === 0 || !admin) {
    console.error("신고 대상(회원/게시글/소원/댓글/관리자)이 부족합니다. 선행 시드를 먼저 실행하세요.");
    process.exit(1);
  }
  if (fortuneResults.length < 2) {
    console.error("신고 대상(운세결과)이 부족합니다. seed_fortune_core.ts를 먼저 실행하세요.");
    process.exit(1);
  }

  const reports = [
    // 1) post 신고 — pending, 담당자 미배정
    {
      targetType: "post",
      targetId: posts[0].id,
      reporterId: users[1].id,
      reason: "광고/스팸성 게시글입니다.",
      assignedAdminId: null,
      action: null,
      status: "pending",
    },
    // 2) post 신고 — reviewed, 담당자 배정됨(검토중)
    {
      targetType: "post",
      targetId: posts[1].id,
      reporterId: users[2].id,
      reason: "부적절한 언어 사용이 포함되어 있습니다.",
      assignedAdminId: admin.id,
      action: null,
      status: "reviewed",
    },
    // 3) post 신고 — actioned(deleted), 대상 게시글 실제로 deleted_by_admin 처리됨
    {
      targetType: "post",
      targetId: posts[2].id,
      reporterId: users[3].id,
      reason: "타인의 사생활을 침해하는 내용입니다.",
      assignedAdminId: admin.id,
      action: "deleted",
      status: "actioned",
    },
    // 4) post 신고 — rejected(반려), 조치 없음
    {
      targetType: "post",
      targetId: posts[0].id,
      reporterId: users[4].id,
      reason: "마음에 안 든다는 이유로 신고합니다.",
      assignedAdminId: admin.id,
      action: null,
      status: "rejected",
    },
    // 5) comment 신고 — pending
    {
      targetType: "comment",
      targetId: comments[0].id,
      reporterId: users[0].id,
      reason: "댓글에 욕설이 포함되어 있습니다.",
      assignedAdminId: null,
      action: null,
      status: "pending",
    },
    // 6) comment 신고 — actioned(deleted)
    {
      targetType: "comment",
      targetId: comments[1].id,
      reporterId: users[5].id,
      reason: "도배성 댓글입니다.",
      assignedAdminId: admin.id,
      action: "deleted",
      status: "actioned",
    },
    // 7) wish 신고 — reviewed
    {
      targetType: "wish",
      targetId: wishes[0].id,
      reporterId: users[3].id,
      reason: "소원 내용이 커뮤니티 가이드라인에 위반됩니다.",
      assignedAdminId: admin.id,
      action: null,
      status: "reviewed",
    },
    // 8) wish 신고 — rejected
    {
      targetType: "wish",
      targetId: wishes[1].id,
      reporterId: users[1].id,
      reason: "단순 신고 오남용으로 판단됩니다.",
      assignedAdminId: admin.id,
      action: null,
      status: "rejected",
    },
    // 9) user 신고 — pending (사용자 자체에 대한 신고, 담당자 미배정)
    {
      targetType: "user",
      targetId: users[5].id,
      reporterId: users[2].id,
      reason: "지속적으로 부적절한 콘텐츠를 게시하는 회원입니다.",
      assignedAdminId: null,
      action: null,
      status: "pending",
    },
    // 10) user 신고 — actioned(suspended), 대상 회원이 이미 suspended 상태(users[5])
    {
      targetType: "user",
      targetId: users[5].id,
      reporterId: users[4].id,
      reason: "다수 회원으로부터 반복 신고가 접수된 회원입니다.",
      assignedAdminId: admin.id,
      action: "suspended",
      status: "actioned",
    },
    // 11) fortune_result 신고 — pending, 담당자 미배정 (05§3.2 명시 대상)
    {
      targetType: "fortune_result",
      targetId: fortuneResults[0].id,
      reporterId: users[0].id,
      reason: "운세 결과 내용이 불쾌하고 부적절합니다.",
      assignedAdminId: null,
      action: null,
      status: "pending",
    },
    // 12) fortune_result 신고 — reviewed, 담당자 배정됨
    {
      targetType: "fortune_result",
      targetId: fortuneResults[1].id,
      reporterId: users[1].id,
      reason: "AI가 생성한 운세 결과에 차별적 표현이 포함되어 있습니다.",
      assignedAdminId: admin.id,
      action: null,
      status: "reviewed",
    },
  ];

  for (const r of reports) {
    await prisma.report.create({
      data: {
        targetType: r.targetType,
        targetId: r.targetId,
        reporterId: r.reporterId,
        reason: r.reason,
        assignedAdminId: r.assignedAdminId,
        action: r.action,
        status: r.status,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }
  console.log(`Reports created: ${reports.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
