// Playwright 디자인 스튜디오 E2E 테스트에 사용한 캠페인(253, 254) 정리.
// 두 캠페인 모두 issuedCount=0, 남은 쿠폰 0건(사전 확인 완료)이므로
// 리비전/캠페인을 삭제해도 발급 이력이나 지갑/포인트 데이터에 영향이 없다.
import { prisma } from "../src/lib/db";

const IDS = [253, 254];

async function main() {
  for (const id of IDS) {
    const c = await prisma.bokjuCouponCampaign.findUnique({ where: { id } });
    if (!c) {
      console.log(`캠페인 ${id} 없음 - 스킵`);
      continue;
    }
    const couponCount = await prisma.bokjuCoupon.count({ where: { campaignId: id } });
    if (c.issuedCount !== 0 || couponCount !== 0) {
      throw new Error(`FAIL: 캠페인 ${id}의 issuedCount(${c.issuedCount}) 또는 남은 쿠폰(${couponCount})이 0이 아님 - 정리 중단(안전 가드)`);
    }
    await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId: id } });
    await prisma.bokjuCouponCampaign.delete({ where: { id } });
    console.log(`✅ 캠페인 ${id}(${c.title}) 및 리비전 삭제 완료`);
  }
}

main()
  .then(() => { console.log("정리 성공"); process.exit(0); })
  .catch((e) => { console.error("정리 실패:", e); process.exit(1); });
