// scripts/verify_criterion5_hash_immutability.ts
// [4단계 완료 증거 — 02e §6 완료기준5] "발행 → 디자인 수정 → 기존 쿠폰
// 이미지 해시 불변"을 실제 배치 발행 경로(startImageGenerationJob, 테스트13/14가
// 방금 배선한 그 경로)로 재현해 end-to-end 로 증명하는 1회성 검증 스크립트.
// 이 스크립트가 만든 캠페인/쿠폰/리비전/이미지 파일은 전부 스스로 정리한다
// (기존 212행/3행에는 전혀 손대지 않는다).
import { prisma } from "../src/lib/db";
import { defaultLayout, addElement } from "../src/lib/bokju-coupon-design/layout";
import { freezeRevision, setCurrentRevision } from "../src/lib/bokju-coupon-design/revision";
import { startImageGenerationJob, getImageJob, readCouponImage } from "../src/lib/bokju-coupon-image-service";
import { createHash } from "node:crypto";
import { rm } from "node:fs/promises";
import path from "node:path";

async function waitForJob(jobId: number, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  let job = await getImageJob(jobId);
  while (job && job.status !== "COMPLETED" && job.status !== "FAILED" && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 200));
    job = await getImageJob(jobId);
  }
  return job;
}

async function main() {
  console.log("── [완료기준5 증거] 발행 → 디자인 수정 → 기존 쿠폰 해시 불변 ──\n");

  // 1) 테스트 캠페인 생성
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: "[검증] 완료기준5 - 해시불변 캠페인",
      grantAmount: 300,
      validFrom: new Date("2026-01-01T00:00:00Z"),
      validTo: new Date("2026-12-31T23:59:59Z"),
      guideText: "QR코드를 찍고 복주머니를 받으세요",
    },
  });
  console.log(`[1] 캠페인 생성 campaignId=${campaign.id}`);

  // 2) rev1 레이아웃 동결 + 캠페인 포인터 지정
  const layoutRev1 = defaultLayout({ width: 1080, height: 1920 }); // 레거시(720x1280)와 명백히 다른 치수로 "신규 경로가 탔다"는 증거를 확실히 한다
  const r1 = await freezeRevision(campaign.id, layoutRev1, { note: "[검증] 최초 디자인", createdBy: "verify-script" });
  await setCurrentRevision(campaign.id, r1.id);
  console.log(`[2] rev1 동결 완료 revId=${r1.id} revNo=${r1.revNo}`);

  // 3) 쿠폰 발행 — issueCoupons()와 동일한 각인 패턴(발행 시점 각인)
  const coupon = await prisma.bokjuCoupon.create({
    data: {
      campaignId: campaign.id,
      couponNo: "VERIFY-C5-" + Date.now(),
      redeemToken: createHash("sha256").update("verify-c5-" + Date.now()).digest("hex").slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: r1.id, // 발행 시점 currentDesignRevisionId(=rev1) 각인
    },
  });
  console.log(`[3] 쿠폰 발행(각인) couponId=${coupon.id} designRevisionId=${coupon.designRevisionId}`);

  // 4) 배치 발행(실제 운영 경로) 1차 실행 → 이미지 생성
  const job1 = await startImageGenerationJob(campaign.id, "verify-script", {
    registerBaseUrl: "https://sintong.kr",
  });
  const jobStatus1 = await waitForJob(job1.jobId);
  if (jobStatus1?.status !== "COMPLETED") {
    throw new Error(`1차 배치 발행 실패: status=${jobStatus1?.status}`);
  }
  const buf1 = await readCouponImage(campaign.id, coupon.id);
  if (!buf1) throw new Error("1차 발행 이미지가 생성되지 않았습니다.");
  const hash1 = createHash("sha256").update(buf1).digest("hex");
  const sharp1 = (await import("sharp")).default;
  const meta1 = await sharp1(buf1).metadata();
  console.log(`[4] 1차 배치 발행 완료 jobId=${job1.jobId} 이미지치수=${meta1.width}x${meta1.height} sha256=${hash1}`);

  // 5) 디자인 "수정" — 눈에 띄게 다른 레이아웃(텍스트 요소 추가)으로 rev2 동결 + 포인터 이동
  const layoutRev2 = addElement(defaultLayout({ width: 1080, height: 1920 }), "text", {
    name: "검증용 수정 문구",
    bind: "static",
    text: "디자인이 수정되었습니다 - rev2",
    x: 540,
    y: 200,
  });
  const r2 = await freezeRevision(campaign.id, layoutRev2, { note: "[검증] 디자인 수정본", createdBy: "verify-script" });
  await setCurrentRevision(campaign.id, r2.id);
  console.log(`[5] 디자인 수정 → rev2 동결 + 포인터 이동 완료 revId=${r2.id} revNo=${r2.revNo}`);
  const campaignAfter = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaign.id } });
  console.log(`    캠페인 현재 포인터 = ${campaignAfter?.currentDesignRevisionId} (rev2=${r2.id})`);
  console.log(`    기존 쿠폰의 designRevisionId = ${coupon.designRevisionId} (여전히 rev1=${r1.id}, 변경되지 않음)`);

  // 6) 같은 배치 발행 경로(startImageGenerationJob)를 다시 실행 — 기존 쿠폰이
  //    디자인 수정 후에도 여전히 rev1(발행 시점 각인값)로 렌더되는지 확인한다.
  //    (campaign.currentDesignRevisionId가 rev2로 바뀌었어도 coupon.designRevisionId는
  //     rev1 그대로이므로, dispatchCouponRender → resolveLayoutForCoupon이 rev1을 읽는다.)
  const job2 = await startImageGenerationJob(campaign.id, "verify-script", {
    registerBaseUrl: "https://sintong.kr",
  });
  const jobStatus2 = await waitForJob(job2.jobId);
  if (jobStatus2?.status !== "COMPLETED") {
    throw new Error(`2차 배치 발행 실패: status=${jobStatus2?.status}`);
  }
  const buf2 = await readCouponImage(campaign.id, coupon.id);
  if (!buf2) throw new Error("2차 발행(재생성) 이미지가 생성되지 않았습니다.");
  const hash2 = createHash("sha256").update(buf2).digest("hex");
  const meta2 = await sharp1(buf2).metadata();
  console.log(`[6] 디자인 수정 후 2차 배치 발행(재실행) 완료 jobId=${job2.jobId} 이미지치수=${meta2.width}x${meta2.height} sha256=${hash2}`);

  // 7) 판정
  console.log("\n── 판정 ──");
  const same = hash1 === hash2;
  console.log(`1차 해시: ${hash1}`);
  console.log(`2차 해시: ${hash2}`);
  console.log(`해시 동일 여부: ${same ? "✅ 동일(불변 — 완료기준5 통과)" : "❌ 다름(불변성 깨짐 — 버그)"}`);

  // 대조군: rev2로 "새로" 발행된 쿠폰은 당연히 다른 이미지가 나와야 한다(그래야
  // "복사-붙여넣기로 통과시킨 가짜 불변"이 아님을 증명할 수 있다).
  const couponRev2 = await prisma.bokjuCoupon.create({
    data: {
      campaignId: campaign.id,
      couponNo: "VERIFY-C5-REV2-" + Date.now(),
      redeemToken: createHash("sha256").update("verify-c5-rev2-" + Date.now()).digest("hex").slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: r2.id,
    },
  });
  const job3 = await startImageGenerationJob(campaign.id, "verify-script", {
    registerBaseUrl: "https://sintong.kr",
  });
  const jobStatus3 = await waitForJob(job3.jobId);
  if (jobStatus3?.status !== "COMPLETED") {
    throw new Error(`3차 배치 발행(대조군) 실패: status=${jobStatus3?.status}`);
  }
  const buf3 = await readCouponImage(campaign.id, couponRev2.id);
  if (!buf3) throw new Error("대조군(rev2 신규쿠폰) 이미지가 생성되지 않았습니다.");
  const hash3 = createHash("sha256").update(buf3).digest("hex");
  console.log(`\n[대조군] rev2로 새로 발행된 쿠폰의 해시: ${hash3}`);
  console.log(`대조군이 1차(rev1)와 다른가: ${hash3 !== hash1 ? "✅ 다름(디자인이 실제로 반영됨을 증명)" : "❌ 같음(의심스러움)"}`);

  // 8) 정리 — 이 스크립트가 만든 것만 지운다
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponImageJob.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: campaign.id } });
  const dir = path.join(process.cwd(), "public", "uploads", "bokju-coupons", `campaign_${campaign.id}`);
  await rm(dir, { recursive: true, force: true }).catch(() => {});
  console.log("\n[정리 완료] 이 스크립트가 만든 캠페인/쿠폰/리비전/이미지 전부 삭제됨.");

  if (!same) {
    console.error("\n❌ 완료기준5 실패 — 해시가 다릅니다.");
    process.exitCode = 1;
  } else {
    console.log("\n✅ 완료기준5 통과 — 발행 후 디자인을 수정해도 기존 쿠폰 이미지는 바이트 단위로 불변입니다.");
  }
}

main()
  .catch((e) => {
    console.error("검증 스크립트 실행 중 오류:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
