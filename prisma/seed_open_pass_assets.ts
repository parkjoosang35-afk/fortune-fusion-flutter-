// 열림패스 첨부파일/광고소스/바인딩 초기 샘플 데이터
// [사용자 요청: 열림패스 관리자 첨부파일/광고소스 연동] §3/§4/§5 샘플
// 실행: npx tsx prisma/seed_open_pass_assets.ts
// 주의: seed_integrated_policy.ts가 먼저 실행되어 pass_policies(1~4)가 존재해야 한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// 실제 서비스 전까지 관리자가 직접 업로드로 교체할 플레이스홀더 이미지(외부 URL).
// [금지 원칙 §15 "배너 이미지 하드코딩 금지"]는 "앱 코드"에 하드코딩하지 말라는 뜻이며,
// 이 시드 스크립트는 관리자 DB에 초기 데이터를 넣는 것이므로 위반이 아니다(운영 시 관리자가
// 첨부파일 관리 화면에서 실제 이미지로 교체하면 된다).
const PLACEHOLDER = {
  heroBanner: "https://picsum.photos/seed/openpass-hero/800/400",
  promoBanner: "https://picsum.photos/seed/openpass-promo/800/400",
  preAdBanner: "https://picsum.photos/seed/openpass-pre-ad/800/400",
  postAdBanner: "https://picsum.photos/seed/openpass-post-ad/800/400",
  fallback: "https://picsum.photos/seed/openpass-fallback/800/400",
  eventBanner: "https://picsum.photos/seed/openpass-event/800/400",
  thumbnail: "https://picsum.photos/seed/openpass-thumb/400/400",
};

async function main() {
  console.log("1) 열림패스 첨부파일 샘플 생성...");
  const attachments = await Promise.all([
    prisma.openPassAttachment.upsert({
      where: { id: 1 },
      update: {},
      create: {
        id: 1,
        fileName: "열림패스 대표 배너(운세 전체 이용권)",
        fileType: "image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.heroBanner,
        thumbnailUrl: PLACEHOLDER.heroBanner,
        purpose: "hero_banner",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 2 },
      update: {},
      create: {
        id: 2,
        fileName: "광고 시청 유도 배너",
        fileType: "image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.promoBanner,
        thumbnailUrl: PLACEHOLDER.promoBanner,
        purpose: "reward_ad_promo",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 3 },
      update: {},
      create: {
        id: 3,
        fileName: "광고 시청 전 안내 배너",
        fileType: "image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.preAdBanner,
        thumbnailUrl: PLACEHOLDER.preAdBanner,
        purpose: "pre_ad_banner",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 4 },
      update: {},
      create: {
        id: 4,
        fileName: "광고 시청 완료 안내 배너",
        fileType: "image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.postAdBanner,
        thumbnailUrl: PLACEHOLDER.postAdBanner,
        purpose: "post_ad_banner",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 5 },
      update: {},
      create: {
        id: 5,
        fileName: "광고 실패 대체 안내 이미지",
        fileType: "ad_fallback_image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.fallback,
        thumbnailUrl: PLACEHOLDER.fallback,
        purpose: "fallback_creative",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 6 },
      update: {},
      create: {
        id: 6,
        fileName: "열림패스 상품 상세 썸네일",
        fileType: "image",
        mimeType: "image/jpeg",
        fileUrl: PLACEHOLDER.thumbnail,
        thumbnailUrl: PLACEHOLDER.thumbnail,
        purpose: "product_thumbnail",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAttachment.upsert({
      where: { id: 7 },
      update: {},
      create: {
        id: 7,
        fileName: "열림패스 이용 안내",
        fileType: "external_link",
        fileUrl: "https://example.com/openpass/terms",
        purpose: "terms_doc",
        displayOrder: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
  ]);
  console.log(`   -> ${attachments.length}건 완료`);

  console.log("2) 열림패스 광고소스 샘플 생성...");
  const adSources = await Promise.all([
    prisma.openPassAdSource.upsert({
      where: { id: 1 },
      update: {},
      create: {
        id: 1,
        sourceName: "AdMob 리워드(안드로이드 기본)",
        sourceType: "admob_rewarded",
        networkName: "AdMob",
        adUnitId: "ca-app-pub-3940256099942544/5224354917", // AdMob 공식 테스트 유닛 ID
        placementId: "open_pass_unlock",
        rewardType: "open_pass_minutes",
        rewardValue: 60,
        cooldownSeconds: 30,
        dailyLimit: 5,
        failoverEnabled: true,
        fallbackAttachmentId: 5,
        testModeEnabled: true,
        isActive: true,
        priority: 0,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAdSource.upsert({
      where: { id: 2 },
      update: {},
      create: {
        id: 2,
        sourceName: "AppLovin 리워드(백업 채널)",
        sourceType: "applovin_rewarded",
        networkName: "AppLovin",
        adUnitId: "TEST_APPLOVIN_UNIT_ID",
        placementId: "open_pass_unlock_backup",
        rewardType: "open_pass_minutes",
        rewardValue: 60,
        cooldownSeconds: 30,
        dailyLimit: 5,
        failoverEnabled: true,
        fallbackAttachmentId: 5,
        testModeEnabled: true,
        isActive: true,
        priority: 1,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
    prisma.openPassAdSource.upsert({
      where: { id: 3 },
      update: {},
      create: {
        id: 3,
        sourceName: "자체 프로모션 광고(내부 이벤트)",
        sourceType: "internal_promo_ad",
        networkName: "internal",
        rewardType: "open_pass_minutes",
        rewardValue: 1440,
        cooldownSeconds: 0,
        dailyLimit: 1,
        failoverEnabled: false,
        fallbackAttachmentId: 5,
        testModeEnabled: false,
        isActive: false,
        priority: 2,
        createdBy: "seed",
        updatedBy: "seed",
      },
    }),
  ]);
  console.log(`   -> ${adSources.length}건 완료`);

  console.log("3) 상품-첨부파일 바인딩 샘플 생성...");
  const attachmentBindings = [
    { passPolicyId: 1, attachmentId: 1, usageType: "hero_banner", isPrimary: true },
    { passPolicyId: 1, attachmentId: 6, usageType: "detail_gallery", isPrimary: false },
    { passPolicyId: 1, attachmentId: 2, usageType: "pre_ad_banner", isPrimary: true },
    { passPolicyId: 1, attachmentId: 4, usageType: "post_ad_banner", isPrimary: true },
    { passPolicyId: 1, attachmentId: 5, usageType: "fallback", isPrimary: true },
    { passPolicyId: 1, attachmentId: 7, usageType: "terms_doc", isPrimary: false },
    { passPolicyId: 3, attachmentId: 1, usageType: "hero_banner", isPrimary: true },
    { passPolicyId: 3, attachmentId: 6, usageType: "detail_gallery", isPrimary: false },
  ];
  for (const b of attachmentBindings) {
    await prisma.openPassProductAttachment.upsert({
      where: {
        passPolicyId_attachmentId_usageType: {
          passPolicyId: b.passPolicyId,
          attachmentId: b.attachmentId,
          usageType: b.usageType,
        },
      },
      update: {},
      create: b,
    });
  }
  console.log(`   -> ${attachmentBindings.length}건 완료`);

  console.log("4) 열림패스 상품 대표 소재 슬롯(hero/promo/fallback) 지정...");
  await prisma.passPolicy.update({ where: { id: 1 }, data: { heroAttachmentId: 1, promoAttachmentId: 2, fallbackAttachmentId: 5 } });
  await prisma.passPolicy.update({ where: { id: 3 }, data: { heroAttachmentId: 1, fallbackAttachmentId: 5 } });
  console.log("   -> 완료");

  console.log("5) 상품-광고소스 바인딩 샘플 생성...");
  const adSourceBindings = [
    { passPolicyId: 1, adSourceId: 1, priority: 0, isPrimary: true, platform: "all" },
    { passPolicyId: 1, adSourceId: 2, priority: 1, isPrimary: false, platform: "all" },
  ];
  for (const b of adSourceBindings) {
    await prisma.openPassProductAdSource.upsert({
      where: {
        passPolicyId_adSourceId_platform: { passPolicyId: b.passPolicyId, adSourceId: b.adSourceId, platform: b.platform },
      },
      update: {},
      create: b,
    });
  }
  console.log(`   -> ${adSourceBindings.length}건 완료`);

  console.log("모든 열림패스 첨부파일/광고소스 시드 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
