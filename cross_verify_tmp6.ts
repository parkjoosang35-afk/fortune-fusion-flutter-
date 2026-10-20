import { prisma } from '@/lib/db';
import { startImageGenerationJob, renderPreviewCouponImage, readCouponImage } from '@/lib/bokju-coupon-image-service';
import { createHash } from 'crypto';
import { rm } from 'fs/promises';
import path from 'path';

async function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  // 1) 임시 테스트 캠페인 + 쿠폰 1장 생성 (운영 데이터 아님, 끝나면 삭제)
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: '2단계-회귀교차검증-임시캠페인',
      grantAmount: 100,
      issueType: 'INDIVIDUAL',
      targetAudience: 'ALL',
      useLimitPerMember: 1,
      guideText: '회귀교차검증용 안내문구',
      distributionMethod: 'DIRECT',
      designTemplate: 'CLASSIC',
      status: 'ACTIVE',
      createdBy: 'step2-cross-verify',
      validFrom: new Date('2026-01-01T00:00:00.000Z'),
      validTo: new Date('2026-12-31T00:00:00.000Z'),
    },
  });
  const coupon = await prisma.bokjuCoupon.create({
    data: {
      campaignId: campaign.id,
      couponNo: 'ST-XVERIFY-0001',
      redeemToken: 'e'.repeat(32),
      status: 'ISSUED',
      expiresAt: new Date('2026-12-31T00:00:00.000Z'),
    },
  });

  try {
    // 2) 실제 "배치 발행" 경로(startImageGenerationJob → runImageJob → 비공개
    //    renderCouponImage())를 그대로 실행한다.
    const { jobId } = await startImageGenerationJob(campaign.id, 'step2-cross-verify', {
      registerBaseUrl: 'https://sintong.kr/coupon-preview',
    });

    // runImageJob 은 fire-and-forget(백그라운드)이므로 완료를 폴링한다.
    let job;
    for (let i = 0; i < 50; i++) {
      job = await prisma.bokjuCouponImageJob.findUnique({ where: { id: jobId } });
      if (job?.status === 'DONE' || job?.status === 'FAILED') break;
      await sleep(200);
    }
    console.log('JOB_STATUS=' + job?.status, 'processed=' + job?.processedCount, 'failed=' + job?.failedCount);

    // 3) 디스크에 생성된 실제 "배치 발행" 이미지를 읽어 해시
    const batchBuf = await readCouponImage(campaign.id, coupon.id);
    if (!batchBuf) throw new Error('배치 발행 이미지가 생성되지 않음');
    const batchHash = createHash('sha256').update(batchBuf).digest('hex');
    console.log('BATCH_PATH_SHA256=' + batchHash, 'size=' + batchBuf.length);

    // 4) 같은 campaign/coupon 값으로 "미리보기" 경로(renderPreviewCouponImage)를
    //    호출 — registerBaseUrl 이 달라 QR 페이로드 문자열은 다르지만, 나머지
    //    렌더 로직(buildCustomDesignSvg 아님, buildSvgForTemplate 경로)이
    //    완전히 동일한 비공개 함수를 타는지 확인하는 것이 목적이다.
    const previewBuf = await renderPreviewCouponImage({
      designTemplate: campaign.designTemplate!,
      campaignTitle: campaign.title,
      grantAmount: campaign.grantAmount,
      guideText: campaign.guideText,
      validFrom: campaign.validFrom,
      validTo: campaign.validTo,
    });
    const previewHash = createHash('sha256').update(previewBuf).digest('hex');
    console.log('PREVIEW_PATH_SHA256=' + previewHash, 'size=' + previewBuf.length);

    // batchHash 와 previewHash 는 couponNo/redeemToken/registerBaseUrl 이 달라
    // "다를 수밖에" 없다(QR 페이로드, 쿠폰번호 텍스트가 다름). 여기서 증명하려는
    // 것은 "두 경로가 같은 렌더 함수·같은 로직을 탄다"이지 "같은 바이트가
    // 나온다"가 아니다 — 같은 로직임은 소스 코드 상 두 호출부가 모두
    // renderCouponImage(비공개, 436번 줄) 하나만 호출한다는 사실로 이미
    // 증명되었다(grep 결과 참고). 이 실행은 그 경로가 "실제로 동작하는지"의
    // 런타임 증거다.
  } finally {
    // 5) 정리 — 임시 캠페인/쿠폰/작업/디스크 이미지 삭제
    const jobs = await prisma.bokjuCouponImageJob.findMany({ where: { campaignId: campaign.id } });
    for (const j of jobs) await prisma.bokjuCouponImageJob.delete({ where: { id: j.id } });
    await prisma.bokjuCoupon.deleteMany({ where: { campaignId: campaign.id } });
    await prisma.bokjuCouponCampaign.delete({ where: { id: campaign.id } });
    const dir = path.join(process.cwd(), 'public', 'uploads', 'bokju-coupons', `campaign_${campaign.id}`);
    await rm(dir, { recursive: true, force: true });
    console.log('CLEANUP_DONE campaign_id=' + campaign.id);
  }
  await prisma.$disconnect();
}
main().catch(async (e) => { console.error('ERROR:', e); await prisma.$disconnect(); process.exit(1); });
