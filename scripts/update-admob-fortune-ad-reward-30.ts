// [마이페이지 리뉴얼 — 복주머니 애드몹 리워드 30개 조정] 사용자 요청
// "애드몹광고을 넣고 복주머니 30개"에 대응 — 이미 adType="admob"으로 등록되어
// 있던 FortuneAd(복주머니 지갑 화면의 "광고 보고 복주머니 받기" 카드)의
// rewardAmount를 5 -> 30으로 변경한다.
//
// [설계 근거] 이 앱에는 광고-보상 흐름이 2종류 있다:
//   1) 프리패스(Pass) 광고 — 쿠팡 파트너스 링크 전용(coupang_pass_sheet.dart),
//      PassPolicyModel.adType은 'image'|'script'만 지원 — admob 미지원.
//   2) 복주머니(Wallet) 광고 — FortuneAdModel, 이미 adType='admob' 완전 지원
//      (FortuneAdWatchDialog가 RewardedAd.load()로 실제 AdMob SDK 연동 완료).
// "애드몹 + 복주머니"라는 요청 문구가 #2(복주머니 지갑 화면)와 정확히
// 일치하므로, 이미 존재하는 #2의 admob 레코드 금액만 30으로 조정한다.
// Flutter 코드는 변경할 필요가 없다 — 보상 금액은 서버(FortuneAd.rewardAmount)
// 값을 그대로 사용하도록 이미 구현되어 있다.
//
// [부가 조정] rewardAmount가 5->30(6배)로 오르면서, 기존
// dailyLimitReward=500(광고 전체 유저 합산 하루 한도)로는 하루 약
// 16명분(500/30)만 지급 가능해 금방 소진된다 — 의도치 않게 기능이
// 하루 중 일찍 막히는 것을 막기 위해 같은 배율(6배)로 3000까지 올린다.
// perUserDailyLimit(1인당 하루 3회)은 요청에 없었으므로 그대로 유지한다.
//
// 실행: cd /home/user/admin_web && npx tsx scripts/update-admob-fortune-ad-reward-30.ts
// idempotent: title로 기존 레코드를 찾아 업데이트만 수행, 없으면 생성한다.
import "dotenv/config";
import { prisma } from "@/lib/db";

async function main() {
  const title = "[애드몹] 보상형 광고 시청하고 복주머니 받기";

  const existing = await prisma.fortuneAd.findFirst({
    where: { title, deletedAt: null },
  });

  if (!existing) {
    const created = await prisma.fortuneAd.create({
      data: {
        title,
        description:
          "AdMob 실제 보상형 광고를 시청하면 복주머니를 지급합니다. (테스트/QA 중에는 항상 구글 테스트 광고 ID가 재생됩니다 — ADMOB_USE_REAL_IDS=true로 빌드해야 실제 광고 ID로 전환됩니다.)",
        adType: "admob",
        imageUrl: null,
        videoUrl: null,
        externalUrl: null,
        adSourceHtml: null,
        rewardAmount: 30,
        watchSeconds: 15,
        isActive: true,
        priority: 0,
        perUserDailyLimit: 3,
        dailyLimitReward: 3000,
        createdBy: "system:update-admob-fortune-ad-reward-30",
        updatedBy: "system:update-admob-fortune-ad-reward-30",
      },
    });
    console.log("레코드가 없어 신규 생성했습니다:", created);
    return;
  }

  const updated = await prisma.fortuneAd.update({
    where: { id: existing.id },
    data: {
      rewardAmount: 30,
      dailyLimitReward: 3000,
      isActive: true,
      updatedBy: "system:update-admob-fortune-ad-reward-30",
    },
  });

  console.log(`기존 레코드(id=${existing.id}) 업데이트 완료:`);
  console.log(`  rewardAmount: ${existing.rewardAmount} -> ${updated.rewardAmount}`);
  console.log(`  dailyLimitReward: ${existing.dailyLimitReward} -> ${updated.dailyLimitReward}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
