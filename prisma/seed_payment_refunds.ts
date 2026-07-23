import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const payments = await prisma.payment.findMany({ orderBy: { id: "asc" } });
  if (payments.length < 12) {
    console.error("선행 시드(payments 12건)가 필요합니다. 먼저 실행하세요.");
    process.exit(1);
  }
  const p = (id: number) => payments.find((x) => x.id === id)!;

  // 04A K-2 스펙: status pending/completed/failed.
  // 05§3.7: "환불 처리 | payment_refunds 신규 생성 워크플로우(원본
  // payments는 상태만 변경)". 시딩은 실제 워크플로우를 재현:
  // - id=6(giftcard, failed 결제)에 대한 환불요청(pending, operator 생성)
  // - id=8(subscription, cancelled 결제)에 대한 환불(completed, super_admin
  //   최종승인 완료 — 이 경우 원본 payments.status가 이미 cancelled로
  //   반영되어 있다고 가정)
  // - id=11(amulet, failed 결제)에 대한 환불요청(pending)
  // - id=10(giftcard, paid 결제, 고객 단순변심 환불)에 대한 완료 처리
  //   1건(completed) — 원본 payments.status를 cancelled로 함께 갱신
  // - id=5(subscription, paid) 환불요청 거부 사례(failed 상태로 종료)
  const refundsData = [
    {
      paymentId: p(6).id,
      amount: p(6).amount,
      reason: "PG 결제 실패에 따른 환불 요청",
      status: "pending",
    },
    {
      paymentId: p(8).id,
      amount: p(8).amount,
      reason: "회원 요청에 의한 구독 취소 환불",
      status: "completed",
      processedAt: new Date(),
    },
    {
      paymentId: p(11).id,
      amount: p(11).amount,
      reason: "결제 실패 재시도 취소",
      status: "pending",
    },
    {
      paymentId: p(10).id,
      amount: p(10).amount,
      reason: "단순 변심 환불 요청(승인 완료)",
      status: "completed",
      processedAt: new Date(),
    },
    {
      paymentId: p(5).id,
      amount: p(5).amount,
      reason: "환불 사유 불충분으로 거부",
      status: "failed",
      processedAt: new Date(),
    },
  ];

  for (const r of refundsData) {
    await prisma.paymentRefund.create({
      data: { ...r, createdBy: "system", updatedBy: "system" },
    });
  }

  // id=10 결제는 환불 완료 처리되었으므로 원본 payments.status를
  // cancelled로 갱신(05§3.7 "원본 payments는 상태만 변경" 원칙 재현)
  await prisma.payment.update({
    where: { id: p(10).id },
    data: { status: "cancelled", updatedBy: "system" },
  });

  console.log(`PaymentRefunds created: ${refundsData.length}건`);
  console.log(`Payment id=${p(10).id} status -> cancelled (환불완료 반영)`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
