// 04A K-1 payments 시드 데이터
// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 1차 소단위(결제 내역
// 조회, 조회 전용). order_type 4종(subscription/giftcard/amulet/luckybag),
// status 3종(paid/failed/cancelled)이 모두 표시되도록 다양하게 시딩한다.
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

  const paymentsData = [
    { userId: u(0), orderType: "subscription", orderRefId: 1, amount: 9900, pgProvider: "toss", pgTxId: "TOSS-TX-0001", status: "paid" },
    { userId: u(1), orderType: "giftcard", orderRefId: 1, amount: 30000, pgProvider: "toss", pgTxId: "TOSS-TX-0002", status: "paid" },
    { userId: u(2), orderType: "amulet", orderRefId: 3, amount: 5900, pgProvider: "iamport", pgTxId: "IMP-TX-0003", status: "paid" },
    { userId: u(3), orderType: "luckybag", orderRefId: 2, amount: 3900, pgProvider: "toss", pgTxId: "TOSS-TX-0004", status: "paid" },
    { userId: u(4), orderType: "subscription", orderRefId: 2, amount: 99000, pgProvider: "toss", pgTxId: "TOSS-TX-0005", status: "paid" },
    { userId: u(5), orderType: "giftcard", orderRefId: 4, amount: 50000, pgProvider: "iamport", pgTxId: "IMP-TX-0006", status: "failed" },
    { userId: u(6), orderType: "amulet", orderRefId: 1, amount: 12900, pgProvider: "toss", pgTxId: "TOSS-TX-0007", status: "paid" },
    { userId: u(7), orderType: "subscription", orderRefId: 3, amount: 9900, pgProvider: "toss", pgTxId: "TOSS-TX-0008", status: "cancelled" },
    { userId: u(8), orderType: "luckybag", orderRefId: 5, amount: 3900, pgProvider: "iamport", pgTxId: "IMP-TX-0009", status: "paid" },
    { userId: u(9), orderType: "giftcard", orderRefId: 6, amount: 100000, pgProvider: "toss", pgTxId: "TOSS-TX-0010", status: "paid" },
    { userId: u(0), orderType: "amulet", orderRefId: 5, amount: 5900, pgProvider: "toss", pgTxId: "TOSS-TX-0011", status: "failed" },
    { userId: u(1), orderType: "subscription", orderRefId: 4, amount: 9900, pgProvider: "toss", pgTxId: "TOSS-TX-0012", status: "paid" },
  ];

  for (const p of paymentsData) {
    await prisma.payment.create({
      data: { ...p, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`Payments created: ${paymentsData.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
