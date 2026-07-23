// 04A F-1 compatibility_requests / F-2 compatibility_results 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 6차(마지막) 소단위(궁합
// 요청/결과 통계, 집계 조회 전용). 통계 화면에서 type별 분포, 회원 상대/
// 비회원 상대 비율, score 분포, 결과 미생성(요청만 있고 result 없는) 케이스를
// 모두 검증할 수 있도록 다양한 조합을 시딩한다.
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
    console.error("선행 시드(회원 10명)가 필요합니다. 먼저 실행하세요.");
    process.exit(1);
  }
  const u = (i: number) => users[i].id;

  // ── compatibility_requests: 8건 (type 4종 x 회원상대/비회원상대 혼합) ──
  const requestsData = [
    { requesterUserId: u(0), targetUserId: u(1), targetInput: null, type: "love" },
    { requesterUserId: u(0), targetUserId: null, targetInput: JSON.stringify({ name: "김민준", birthDate: "1995-03-12", birthTime: "14:30" }), type: "love" },
    { requesterUserId: u(1), targetUserId: u(2), targetInput: null, type: "friend" },
    { requesterUserId: u(2), targetUserId: null, targetInput: JSON.stringify({ name: "이서연", birthDate: "1998-07-22", birthTime: null }), type: "business" },
    { requesterUserId: u(3), targetUserId: u(4), targetInput: null, type: "family" },
    { requesterUserId: u(4), targetUserId: u(5), targetInput: null, type: "love" },
    { requesterUserId: u(6), targetUserId: null, targetInput: JSON.stringify({ name: "박지훈", birthDate: "1990-11-05", birthTime: "09:00" }), type: "friend" },
    // 결과 미생성 케이스(요청만 존재, AI 결과 산출 전 or 실패) — 통계 화면의
    // "결과 대기/미생성" 집계 로직 검증용
    { requesterUserId: u(7), targetUserId: u(8), targetInput: null, type: "love" },
  ];

  const createdRequests = [];
  for (const r of requestsData) {
    const created = await prisma.compatibilityRequest.create({
      data: { ...r, createdBy: "system", updatedBy: "system" },
    });
    createdRequests.push(created);
  }
  console.log(`CompatibilityRequests created: ${createdRequests.length}건`);

  // ── compatibility_results: 7건 (마지막 요청 1건은 결과 미생성 상태로 남김) ──
  const resultsData = [
    {
      requestId: createdRequests[0].id,
      score: 87,
      detail: JSON.stringify({ saju: 90, mbti: 82, interest: 88, value: 85 }),
    },
    {
      requestId: createdRequests[1].id,
      score: 65,
      detail: JSON.stringify({ saju: 70, mbti: 55, interest: 68, value: 62 }),
    },
    {
      requestId: createdRequests[2].id,
      score: 92,
      detail: JSON.stringify({ saju: 88, mbti: 95, interest: 93, value: 91 }),
    },
    {
      requestId: createdRequests[3].id,
      score: 45,
      detail: JSON.stringify({ saju: 40, mbti: 50, interest: 42, value: 48 }),
    },
    {
      requestId: createdRequests[4].id,
      score: 78,
      detail: JSON.stringify({ saju: 80, mbti: 75, interest: 79, value: 77 }),
    },
    {
      requestId: createdRequests[5].id,
      score: 34,
      detail: JSON.stringify({ saju: 30, mbti: 38, interest: 32, value: 36 }),
    },
    {
      requestId: createdRequests[6].id,
      score: 71,
      detail: JSON.stringify({ saju: 68, mbti: 74, interest: 70, value: 72 }),
    },
    // createdRequests[7] (u7↔u8, love)은 의도적으로 결과 없음 — "미생성" 케이스
  ];

  for (const res of resultsData) {
    await prisma.compatibilityResult.create({
      data: { ...res, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`CompatibilityResults created: ${resultsData.length}건 (요청 8건 중 결과 미생성 1건)`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
