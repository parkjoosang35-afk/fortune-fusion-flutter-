import { randomUUID } from "node:crypto";
import { prisma } from "../src/lib/db";
import { createCampaign, issueCoupons, redeemCoupon, BokjuCouponError } from "../src/lib/bokju-coupon-service";

async function main() {
  console.log("=== [준비] 테스트용 캠페인 생성(1인당 한도=2) + 쿠폰 5장 발행 ===");
  const now = new Date();
  const validFrom = now;
  const validTo = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

  const { campaignId } = await createCampaign({
    title: "[자동테스트] 1인당한도 등록검증용",
    grantAmount: 10,
    issueType: "INDIVIDUAL",
    targetAudience: "ALL",
    useLimitPerMember: 2,
    totalIssueLimit: 5,
    validFrom,
    validTo,
    distributionMethod: "DIRECT",
  }, "test-script");
  await prisma.bokjuCouponCampaign.update({ where: { id: campaignId }, data: { status: "ACTIVE" } });
  await issueCoupons(campaignId, 5, "test-script");

  const coupons = await prisma.bokjuCoupon.findMany({ where: { campaignId }, orderBy: { id: "asc" } });
  console.log("발행된 쿠폰 수:", coupons.length);

  // 테스트 유저 1명 사용(기존 유저 1번) - 지갑 잔액 변동은 테스트 후 복원하지 않지만
  // earnLuckPouch는 PointHistory만 추가하는 구조이므로 복원 대신 생성한 레코드만 정리한다.
  const testUser = await prisma.user.findUnique({ where: { id: 1 } });
  if (!testUser) throw new Error("테스트 유저(id=1)를 찾을 수 없습니다.");
  console.log("테스트 유저:", testUser.id, testUser.email);

  // [잔액 원복 검증] 테스트 시작 전 관련 유저들의 지갑 잔액을 스냅샷
  const walletsBefore = await prisma.wallet.findMany({
    where: { userId: { in: [1, 2, 3] }, currencyType: "POINT" },
  });
  const balanceBefore = new Map(walletsBefore.map((w) => [w.userId, w.balance]));
  console.log("테스트 전 잔액 스냅샷:", Object.fromEntries(balanceBefore));

  console.log("\n=== [테스트 A] 1번째 쿠폰 등록 → 성공해야 함 ===");
  const r1 = await redeemCoupon({ userId: testUser.id, token: coupons[0].redeemToken, idempotencyKey: randomUUID(), isNewMember: false });
  console.log("결과:", r1);
  if (!r1.ok) throw new Error("FAIL: 1번째 등록이 실패함 - " + r1.message);
  console.log("✅ 테스트A 통과\n");

  console.log("=== [테스트 B] 같은 유저가 2번째 쿠폰 등록(한도=2, 2번째까지 허용) → 성공해야 함 ===");
  const r2 = await redeemCoupon({ userId: testUser.id, token: coupons[1].redeemToken, idempotencyKey: randomUUID(), isNewMember: false });
  console.log("결과:", r2);
  if (!r2.ok) throw new Error("FAIL: 2번째 등록이 실패함 - " + r2.message);
  console.log("✅ 테스트B 통과\n");

  console.log("=== [테스트 C] 같은 유저가 3번째 쿠폰 등록 시도(한도=2 초과) → 차단되어야 함(LIMIT_EXCEEDED) ===");
  const r3 = await redeemCoupon({ userId: testUser.id, token: coupons[2].redeemToken, idempotencyKey: randomUUID(), isNewMember: false });
  console.log("결과:", r3);
  if (r3.ok) throw new Error("FAIL: 한도초과인데 3번째 등록이 성공함(버그)");
  if (r3.code !== "LIMIT_EXCEEDED") throw new Error("FAIL: 예상한 에러코드가 아님: " + r3.code);
  console.log("✅ 테스트C 통과: 올바르게 차단됨 →", r3.message, "\n");

  console.log("=== [테스트 D] 이미 등록한 1번째 쿠폰을 같은 유저가 재등록 시도(중복 등록) → ALREADY_USED로 차단 ===");
  const r4 = await redeemCoupon({ userId: testUser.id, token: coupons[0].redeemToken, idempotencyKey: randomUUID(), isNewMember: false });
  console.log("결과:", r4);
  if (r4.ok) throw new Error("FAIL: 중복 등록인데 성공함(버그)");
  if (r4.code !== "ALREADY_USED") throw new Error("FAIL: 예상한 에러코드가 아님: " + r4.code);
  console.log("✅ 테스트D 통과: 중복 등록 차단됨 →", r4.message, "\n");

  console.log("=== [테스트 E] 다른 유저(id=2)가 4번째 쿠폰 등록 → 본인 한도와 무관하게 성공해야 함(1인당 한도는 유저별 독립) ===");
  const testUser2 = await prisma.user.findUnique({ where: { id: 2 } });
  if (!testUser2) throw new Error("테스트 유저(id=2)를 찾을 수 없습니다.");
  const r5 = await redeemCoupon({ userId: testUser2.id, token: coupons[3].redeemToken, idempotencyKey: randomUUID(), isNewMember: false });
  console.log("결과:", r5);
  if (!r5.ok) throw new Error("FAIL: 다른 유저의 첫 등록이 실패함 - " + r5.message);
  console.log("✅ 테스트E 통과: 1인당 한도는 유저별로 독립적으로 적용됨\n");

  console.log("=== [테스트 F] 동시성 — 같은 유저(id=3, 신규)가 남은 5번째 쿠폰 1장에 대해 동시 등록 시도 10건 → 정확히 1건만 성공해야 함 ===");
  const testUser3 = await prisma.user.findUnique({ where: { id: 3 } });
  if (!testUser3) throw new Error("테스트 유저(id=3)를 찾을 수 없습니다.");
  const concurrentResults = await Promise.all(
    Array.from({ length: 10 }, () =>
      redeemCoupon({ userId: testUser3.id, token: coupons[4].redeemToken, idempotencyKey: randomUUID(), isNewMember: false })
    )
  );
  const successCount = concurrentResults.filter((r) => r.ok).length;
  const dupCount = concurrentResults.filter((r) => !r.ok && r.code === "ALREADY_USED").length;
  console.log(`동시 등록 시도 10건 중 성공 ${successCount}건, 중복차단(ALREADY_USED) ${dupCount}건`);
  if (successCount !== 1) throw new Error(`FAIL: 동시 등록 성공 건수가 1이 아님(${successCount}) - 동시성 제어 실패(이중 지급 위험)`);
  console.log("✅ 테스트F 통과: 동시 등록 요청에도 정확히 1건만 성공(이중 적립 방지 확인)\n");

  console.log("🎉 전체 6개 테스트(A~F) 모두 통과!");

  console.log("\n=== 테스트 데이터 정리 ===");
  const redemptions = await prisma.bokjuCouponRedemption.findMany({ where: { campaignId } });
  const pointHistoryIds: number[] = [];
  // PointHistory 복원(지급된 복주머니 되돌리기) - sourceType=bokju_coupon, sourceId=coupon.id 로 추적
  const couponIds = coupons.map((c) => c.id);
  const histories = await prisma.pointHistory.findMany({ where: { sourceType: "bokju_coupon", sourceId: { in: couponIds } } });
  console.log(`생성된 PointHistory ${histories.length}건, Redemption ${redemptions.length}건 - 삭제 진행`);
  for (const h of histories) {
    // 지갑 잔액 복원 후 기록 삭제
    await prisma.wallet.updateMany({ where: { userId: h.userId, currencyType: "POINT" }, data: { balance: { decrement: h.amount } } });
  }
  await prisma.pointHistory.deleteMany({ where: { sourceType: "bokju_coupon", sourceId: { in: couponIds } } });
  await prisma.bokjuCouponRedemption.deleteMany({ where: { campaignId } });
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
  console.log("테스트 캠페인/쿠폰/등록이력/포인트이력 삭제 완료");

  // [잔액 원복 검증] 정리 후 잔액이 테스트 시작 전과 동일한지 확인
  const walletsAfter = await prisma.wallet.findMany({
    where: { userId: { in: [1, 2, 3] }, currencyType: "POINT" },
  });
  for (const w of walletsAfter) {
    const before = balanceBefore.get(w.userId) ?? 0;
    console.log(`유저 ${w.userId} 잔액: 이전=${before}, 이후=${w.balance}`);
    if (before !== w.balance) {
      throw new Error(`FAIL: 유저 ${w.userId}의 지갑 잔액이 원복되지 않음(이전 ${before} vs 이후 ${w.balance})`);
    }
  }
  console.log("✅ 모든 테스트 유저 지갑 잔액 원복 확인 완료");
}

main()
  .then(() => { console.log("\n=== 전체 테스트 스크립트 성공 종료 ==="); process.exit(0); })
  .catch((e) => { console.error("\n❌ 테스트 실패:", e); process.exit(1); });
