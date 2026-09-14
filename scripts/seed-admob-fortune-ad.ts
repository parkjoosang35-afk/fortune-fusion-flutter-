// [애드몹 실제 연동] 실제 앱에서 AdMob 보상형(리워드) 광고를 시청하고
// 복주머니를 받는 흐름을 테스트하기 위한 FortuneAd(adType="admob") 1건을
// 등록하는 1회성 스크립트(재실행 시 idempotent — title로 기존 레코드 확인).
//
// 실행: cd /home/user/admin_web && npx tsx scripts/seed-admob-fortune-ad.ts
//
// 주의: 여기서 설정하는 rewardAmount(복주머니 개수)가 실제 앱에서 지급되는
// 유일한 기준이다. AdMob 콘솔에 등록된 리워드 설정값(예: "1개")은 절대
// 지급량 결정에 쓰이지 않는다 — 오직 이 값만 사용된다.
import { prisma } from "@/lib/db";

async function main() {
  const title = "[애드몹] 보상형 광고 시청하고 복주머니 받기";

  const existing = await prisma.fortuneAd.findFirst({
    where: { title, deletedAt: null },
  });
  if (existing) {
    console.log(`이미 존재합니다 (id=${existing.id}). 스킵합니다.`);
    console.log(existing);
    return;
  }

  const created = await prisma.fortuneAd.create({
    data: {
      title,
      description:
        "AdMob 실제 보상형 광고를 시청하면 복주머니를 지급합니다. (테스트/QA 중에는 항상 구글 테스트 광고 ID가 재생됩니다 — ADMOB_USE_REAL_IDS=true로 빌드해야 실제 광고 ID로 전환됩니다.)",
      adType: "admob",
      // admob 타입은 콘텐츠 URL이 필요 없다 — 광고 자체를 AdMob SDK가 결정.
      imageUrl: null,
      videoUrl: null,
      externalUrl: null,
      adSourceHtml: null,
      rewardAmount: 5, // 1회 시청 완료 시 지급할 복주머니 개수 (관리자가 결정)
      watchSeconds: 15, // 서버 검증 기준 최소 시청 시간(초) — start()/complete() 세션에 사용
      isActive: true,
      priority: 0,
      perUserDailyLimit: 3, // 회원당 하루 최대 3회
      dailyLimitReward: 500, // 이 광고 전체 유저 합산 하루 최대 500개까지 지급
      createdBy: "system:seed-admob-fortune-ad",
      updatedBy: "system:seed-admob-fortune-ad",
    },
  });

  console.log("생성 완료:");
  console.log(created);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
