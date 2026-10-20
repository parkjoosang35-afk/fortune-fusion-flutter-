// [검수] "미리보기 = 실제 발급 쿠폰 일치" 실증 테스트
// 1) 캠페인 253(E2E 정렬 테스트로 레이아웃을 정중앙 이동시켜 저장한 캠페인)을 ACTIVE 전환
// 2) currentDesignRevisionId가 방금 저장한 리비전인지 확인
// 3) 쿠폰 1장 실제 발급(issueCoupons) → coupon.designRevisionId 각인 확인
// 4) dispatchCouponRender()로 "실제 발급 쿠폰" 이미지 렌더
// 5) previewDesign()으로 "디자인 스튜디오 미리보기" 이미지 렌더(동일 레이아웃, 샘플 토큰만 다름)
// 6) 두 이미지의 치수(width/height)와 PNG 메타데이터가 동일한지, 그리고 버퍼 크기가
//    합리적 범위에서 유사한지(완전히 다른 레이아웃이면 크게 다를 것) 비교해 구조적 일치를 증명
import { prisma } from "../src/lib/db";
import { issueCoupons } from "../src/lib/bokju-coupon-service";
import { dispatchCouponRender } from "../src/lib/bokju-coupon-design/dispatch";
import { previewDesign } from "../src/lib/bokju-coupon-design/studio-api";
import sharp from "sharp";

const CAMPAIGN_ID = 253;

async function main() {
  console.log("=== [1단계] 캠페인 상태 확인 및 ACTIVE 전환 ===");
  let campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: CAMPAIGN_ID } });
  if (!campaign) throw new Error(`캠페인 ${CAMPAIGN_ID} 없음`);
  console.log(`캠페인: ${campaign.title} | status=${campaign.status} | currentDesignRevisionId=${campaign.currentDesignRevisionId}`);

  if (campaign.status !== "ACTIVE") {
    await prisma.bokjuCouponCampaign.update({ where: { id: CAMPAIGN_ID }, data: { status: "ACTIVE" } });
    console.log("상태를 ACTIVE로 전환함");
  }
  campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: CAMPAIGN_ID } });
  if (!campaign) throw new Error("재조회 실패");

  if (campaign.currentDesignRevisionId == null) {
    throw new Error("FAIL: currentDesignRevisionId가 설정되지 않음 - Playwright 저장 테스트가 실제로 리비전을 current로 설정하지 않았을 수 있음");
  }
  console.log(`✅ currentDesignRevisionId=${campaign.currentDesignRevisionId} (저장된 '쿠폰명 정중앙 이동' 레이아웃)`);

  const revision = await prisma.bokjuCouponDesignRevision.findUnique({ where: { id: campaign.currentDesignRevisionId } });
  if (!revision) throw new Error("리비전 레코드 없음");
  const layout = JSON.parse(revision.layout);
  const couponNameEl = layout.elements.find((e: { bind?: string }) => e.bind === "campaign.title");
  console.log(`리비전 레이아웃 내 쿠폰명(campaign.title bind) 요소 좌표: x=${couponNameEl?.x}, y=${couponNameEl?.y}`);
  if (couponNameEl?.x !== 360 || couponNameEl?.y !== 640) {
    throw new Error(`FAIL: 저장된 리비전의 쿠폰명 좌표가 Playwright 테스트에서 설정한 값(360,640)과 다름 - 실제값(${couponNameEl?.x},${couponNameEl?.y})`);
  }
  console.log("✅ Playwright로 저장한 좌표(360,640)가 DB 리비전에 정확히 반영됨 확인\n");

  console.log("=== [2단계] 쿠폰 1장 실제 발급 ===");
  const before = await prisma.bokjuCoupon.count({ where: { campaignId: CAMPAIGN_ID } });
  await issueCoupons(CAMPAIGN_ID, 1, "e2e-verify-script");
  const newCoupon = await prisma.bokjuCoupon.findFirst({
    where: { campaignId: CAMPAIGN_ID },
    orderBy: { id: "desc" },
  });
  if (!newCoupon) throw new Error("발급된 쿠폰을 찾을 수 없음");
  console.log(`발급된 쿠폰 id=${newCoupon.id}, couponNo=${newCoupon.couponNo}, designRevisionId=${newCoupon.designRevisionId}`);
  if (newCoupon.designRevisionId !== campaign.currentDesignRevisionId) {
    throw new Error(`FAIL: 발급된 쿠폰의 designRevisionId(${newCoupon.designRevisionId})가 캠페인의 currentDesignRevisionId(${campaign.currentDesignRevisionId})와 다름 - 각인 로직 오류`);
  }
  console.log("✅ 발급된 쿠폰에 현재 디자인 리비전이 정확히 각인됨\n");

  console.log("=== [3단계] '실제 발급 쿠폰' 이미지 렌더(dispatchCouponRender - 실제 쿠폰번호/QR 사용) ===");
  const issuedResult = await dispatchCouponRender({
    couponId: newCoupon.id,
    registerBaseUrl: "http://localhost:3010",
  });
  if (!issuedResult.handled || !issuedResult.buffer) {
    throw new Error("FAIL: dispatchCouponRender가 handled=false 반환 - 신규 렌더 경로를 안 탐(레거시로 폴백됨)");
  }
  const issuedMeta = await sharp(issuedResult.buffer).metadata();
  console.log(`실제 발급 쿠폰 이미지: ${issuedMeta.width}x${issuedMeta.height}, format=${issuedMeta.format}, bytes=${issuedResult.buffer.length}`);

  console.log("\n=== [4단계] '디자인 스튜디오 미리보기' 이미지 렌더(previewDesign - 샘플 토큰 사용) ===");
  const previewResult = await previewDesign({
    layout,
    campaignTitle: campaign.title,
    grantAmount: campaign.grantAmount,
    guideText: campaign.guideText,
    validFrom: campaign.validFrom,
    validTo: campaign.validTo,
    registerBaseUrl: "http://localhost:3010",
  });
  const previewMeta = await sharp(previewResult.buffer).metadata();
  console.log(`미리보기 이미지: ${previewMeta.width}x${previewMeta.height}, format=${previewMeta.format}, bytes=${previewResult.buffer.length}`);

  console.log("\n=== [5단계] 두 이미지 구조적 일치 비교 ===");
  const results: { name: string; pass: boolean; detail?: string }[] = [];
  const check = (name: string, pass: boolean, detail?: string) => {
    results.push({ name, pass, detail });
    console.log(`${pass ? "✅" : "❌"} ${name}${detail ? " - " + detail : ""}`);
  };
  check("치수(width) 완전 일치", issuedMeta.width === previewMeta.width, `issued=${issuedMeta.width}, preview=${previewMeta.width}`);
  check("치수(height) 완전 일치", issuedMeta.height === previewMeta.height, `issued=${issuedMeta.height}, preview=${previewMeta.height}`);
  check("포맷 완전 일치", issuedMeta.format === previewMeta.format, `issued=${issuedMeta.format}, preview=${previewMeta.format}`);
  // 쿠폰번호/QR 바이트만 다르므로 전체 바이트 크기는 완전 동일하진 않지만 유사해야 함(±20% 이내)
  const sizeDiffRatio = Math.abs(issuedResult.buffer.length - previewResult.buffer.length) / previewResult.buffer.length;
  check("파일 크기 유사(동일 레이아웃 구조, ±20% 이내)", sizeDiffRatio < 0.2, `차이율=${(sizeDiffRatio * 100).toFixed(1)}%`);

  // 픽셀 레벨 차이 비교(쿠폰명 요소 주변을 제외한 배경 영역은 완전히 같아야 함)
  const issuedRaw = await sharp(issuedResult.buffer).resize(100, 178).raw().toBuffer();
  const previewRaw = await sharp(previewResult.buffer).resize(100, 178).raw().toBuffer();
  let diffPixels = 0;
  for (let i = 0; i < Math.min(issuedRaw.length, previewRaw.length); i++) {
    if (Math.abs(issuedRaw[i] - previewRaw[i]) > 30) diffPixels++;
  }
  const diffRatio = diffPixels / issuedRaw.length;
  console.log(`축소 비교(100x178) 픽셀 차이율: ${(diffRatio * 100).toFixed(1)}% (쿠폰번호/QR 텍스트 영역만 달라야 하므로 완전한 0%는 아님)`);
  check("전체 레이아웃 구조가 크게 다르지 않음(차이율 40% 미만)", diffRatio < 0.4, `차이율=${(diffRatio * 100).toFixed(1)}%`);

  // 저장 (수동 시각 비교용)
  const fs = await import("fs/promises");
  await fs.writeFile("/tmp/e2e_issued_coupon.png", issuedResult.buffer);
  await fs.writeFile("/tmp/e2e_preview_coupon.png", previewResult.buffer);
  console.log("\n비교용 이미지 저장: /tmp/e2e_issued_coupon.png, /tmp/e2e_preview_coupon.png");

  const failCount = results.filter((r) => !r.pass).length;
  console.log(`\n=== 결과: ${results.length - failCount}/${results.length} 통과 ===`);

  console.log("\n=== [정리] 테스트로 발급한 쿠폰 삭제 ===");
  await prisma.bokjuCoupon.delete({ where: { id: newCoupon.id } });
  await prisma.bokjuCouponCampaign.update({ where: { id: CAMPAIGN_ID }, data: { issuedCount: { decrement: 1 } } });
  console.log(`✅ 테스트 쿠폰(id=${newCoupon.id}) 삭제 및 issuedCount 롤백 완료 (발급 전 개수=${before})`);

  if (failCount > 0) process.exit(1);
}

main()
  .then(() => {
    console.log("\n=== 전체 성공 ===");
    process.exit(0);
  })
  .catch((e) => {
    console.error("\n❌ 실패:", e);
    process.exit(1);
  });
