// 상점 관리 — 상품권 생명주기(발급/사용/취소/환불/재발급/만료) 목업 데이터 시딩 스크립트
// 04A J-2 giftcard_issues / J-3 giftcard_usages / J-4 giftcard_cancels /
// J-5 giftcard_refunds / J-6 giftcard_reissues / J-7 giftcard_expiry_logs
// 회원 활동 결과 데이터이므로 조회 전용 화면(shop/giftcards 페이지 내 섹션)용 샘플 생성.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

function daysAgo(n: number): Date {
  return new Date(Date.now() - n * 86400000);
}

async function seedGiftcardLifecycle(): Promise<void> {
  console.log("[seed_giftcard_lifecycle] giftcard_issues 시딩...");

  const existingCount = await prisma.giftcardIssue.count();
  if (existingCount > 0) {
    console.log(`[seed_giftcard_lifecycle]    -> 이미 ${existingCount}건 존재, 스킵`);
    return;
  }

  const users = await prisma.user.findMany({ orderBy: { id: "asc" }, take: 10 });
  const products = await prisma.giftcardProduct.findMany({
    where: { deletedAt: null, isActive: true },
    orderBy: { id: "asc" },
  });
  const wallets = await prisma.wallet.findMany({ orderBy: { id: "asc" } });

  if (users.length === 0 || products.length === 0) {
    console.warn(
      "[seed_giftcard_lifecycle] 경고: users 또는 giftcard_products가 없어 시딩을 스킵합니다.",
    );
    return;
  }

  const walletByUserId = new Map(wallets.map((w) => [w.userId, w] as const));

  type IssueRow = { id: number; userId: number; productId: number; status: string };
  const issues: IssueRow[] = [];

  // 회원 x 상품권 상품을 순환 배정해 issues 12건을 상태별로 생성
  // (issued 5 / used 예정 3 / cancelled 2 / expired 1 / failed 1)
  const PLAN: { status: string; count: number }[] = [
    { status: "issued", count: 5 },
    { status: "cancelled", count: 2 },
    { status: "expired", count: 1 },
    { status: "failed", count: 1 },
  ];

  let seq = 0;
  for (const { status, count } of PLAN) {
    for (let k = 0; k < count; k++) {
      const user = users[seq % users.length];
      const product = products[seq % products.length];
      const daysAgoIssued = 30 - seq;
      const issuedAt = status === "failed" ? null : daysAgo(daysAgoIssued);
      const expiresAt =
        status === "failed" ? null : daysAgo(daysAgoIssued - product.validDays);

      const issue = await prisma.giftcardIssue.create({
        data: {
          userId: user.id,
          productId: product.id,
          pointSpent: product.requiredPoint,
          issuedCode: status === "issued" || status === "cancelled" ? `GC-${1000 + seq}` : null,
          issuedAt,
          expiresAt,
          status,
          createdAt: daysAgo(daysAgoIssued),
          createdBy: "system_seed",
          updatedBy: "system_seed",
        },
      });
      issues.push({ id: issue.id, userId: user.id, productId: product.id, status });
      seq++;
    }
  }
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_issues ${issues.length}건 생성`);

  // J-3 giftcard_usages: issued 상태 중 일부(2건)는 이미 사용완료된 것으로 표시.
  // [스펙 준수] 04A J-2 giftcard_issues.status(Base) 허용값은
  // requested/issued/failed/cancelled/expired 뿐이며 "used"는 정의되어 있지 않다.
  // "사용완료" 여부는 issue.status를 변경하는 것이 아니라 giftcard_usages(UQ issue_id)
  // 레코드의 존재 여부로 판단하는 것이 설계 의도이므로, issue.status는 issued로 유지한다.
  const issuedOnes = issues.filter((i) => i.status === "issued");
  let usageCreated = 0;
  for (const issue of issuedOnes.slice(0, 2)) {
    await prisma.giftcardUsage.create({
      data: {
        issueId: issue.id,
        usedAt: daysAgo(1),
        usedLocationMeta: JSON.stringify({ store: "강남점", partner_callback: "ok" }),
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    usageCreated++;
  }
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_usages ${usageCreated}건 생성`);

  // J-4 giftcard_cancels + J-5 giftcard_refunds: cancelled 상태 issues에 대해 취소/환불 이력 생성
  const cancelledOnes = issues.filter((i) => i.status === "cancelled");
  let cancelCreated = 0;
  let refundCreated = 0;
  for (const issue of cancelledOnes) {
    const cancel = await prisma.giftcardCancel.create({
      data: {
        issueId: issue.id,
        reason: "회원 요청에 의한 취소",
        cancelledAt: daysAgo(5),
        refundedPoint: 5000,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    cancelCreated++;

    // 환불 원장 레코드(point_histories) 생성 후 refund에 연결
    const wallet = walletByUserId.get(issue.userId);
    if (wallet) {
      const ph = await prisma.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId: issue.userId,
          amount: 5000,
          type: "earn",
          sourceType: "refund",
          sourceId: cancel.id,
          balanceAfter: wallet.balance + 5000,
          memo: "상품권 취소 환불",
        },
      });
      await prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: wallet.balance + 5000 },
      });
      walletByUserId.set(issue.userId, { ...wallet, balance: wallet.balance + 5000 });

      await prisma.giftcardRefund.create({
        data: {
          cancelId: cancel.id,
          refundPointHistoryId: ph.id,
          status: "completed",
          createdBy: "system_seed",
          updatedBy: "system_seed",
        },
      });
      refundCreated++;
    }
  }
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_cancels ${cancelCreated}건 생성`);
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_refunds ${refundCreated}건 생성`);

  // J-6 giftcard_reissues: issued 상태 중 1건을 "코드 유실"로 재발급 처리 (신규 issue 생성)
  let reissueCreated = 0;
  const reissueSource = issuedOnes[issuedOnes.length - 1];
  if (reissueSource) {
    const product = products.find((p) => p.id === reissueSource.productId) ?? products[0];
    const newIssue = await prisma.giftcardIssue.create({
      data: {
        userId: reissueSource.userId,
        productId: reissueSource.productId,
        pointSpent: 0, // 재발급은 재결제 없음
        issuedCode: `GC-RE-${reissueSource.id}`,
        issuedAt: daysAgo(1),
        expiresAt: daysAgo(1 - product.validDays),
        status: "issued",
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    await prisma.giftcardReissue.create({
      data: {
        originalIssueId: reissueSource.id,
        newIssueId: newIssue.id,
        reason: "코드 유실로 인한 재발급",
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    reissueCreated++;
  }
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_reissues ${reissueCreated}건 생성`);

  // J-7 giftcard_expiry_logs: expired 상태 issues에 대해 만료 배치 로그 생성
  const expiredOnes = issues.filter((i) => i.status === "expired");
  let expiryLogCreated = 0;
  for (const issue of expiredOnes) {
    await prisma.giftcardExpiryLog.create({
      data: {
        issueId: issue.id,
        expiredAt: daysAgo(1),
      },
    });
    expiryLogCreated++;
  }
  console.log(`[seed_giftcard_lifecycle]    -> giftcard_expiry_logs ${expiryLogCreated}건 생성`);
}

async function main() {
  console.log("=== 상품권 생명주기 목업 데이터 시딩 시작 ===");
  await seedGiftcardLifecycle();
  console.log("=== 시딩 완료 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
