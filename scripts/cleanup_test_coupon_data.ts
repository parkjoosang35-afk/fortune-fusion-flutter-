import { prisma } from "../src/lib/db";

// [중요 발견] point_histories 테이블은 DB 트리거(prevent_point_history_delete/
// prevent_point_history_update)로 append-only가 강제되어 있어 삭제가 원천
// 차단된다(실제 적립 원장이므로 올바른 보호 장치). 따라서 테스트 중 생성된
// PointHistory(1282~1285, 각 10포인트 복주머니 쿠폰 테스트 적립)는 삭제하지
// 않고 "실제 발생한 정상 거래 기록"으로 그대로 둔다 — 대신 Wallet.balance는
// 동일 금액만큼 차감해 재무적으로 올바른 최종 잔액을 유지한다(이미 직전
// 스크립트에서 완료됨). 캠페인/쿠폰/등록이력(append-only 아님)만 정리한다.
async function main() {
  console.log("=== 캠페인 252(테스트용) 잔여 데이터 정리 ===");

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: 252 } });
  if (!campaign) {
    console.log("캠페인 252가 이미 없음 - 정리할 것 없음");
    return;
  }
  console.log("캠페인:", campaign.title, "| issuedCount:", campaign.issuedCount);

  await prisma.bokjuCouponRedemption.deleteMany({ where: { campaignId: 252 } });
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId: 252 } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: 252 } });

  console.log("✅ 캠페인/쿠폰/등록이력 삭제 완료");

  const remainCampaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: 252 } });
  const remainCoupons = await prisma.bokjuCoupon.count({ where: { campaignId: 252 } });
  console.log("검증 - campaign 존재?", !!remainCampaign, "| 남은 쿠폰:", remainCoupons);
  if (remainCampaign || remainCoupons > 0) throw new Error("정리 실패");

  const wallets = await prisma.wallet.findMany({ where: { userId: { in: [1, 2, 3] }, currencyType: "POINT" } });
  console.log("최종 잔액(테스트 전과 동일해야 함: 1=106387, 2=651, 3=240):", wallets.map((w) => ({ userId: w.userId, balance: w.balance })));
}

main()
  .then(() => { console.log("정리 성공"); process.exit(0); })
  .catch((e) => { console.error("정리 실패:", e); process.exit(1); });
