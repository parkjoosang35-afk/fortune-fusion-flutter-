import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const MOCK_SOURCES = [
  {
    sourceName: "[테스트] 리워드 성공",
    sourceType: "mock_rewarded_success",
    rewardType: "open_pass_minutes",
    rewardValue: 30,
    simulatedDurationSeconds: 4,
    failMode: null,
    priority: 1,
  },
  {
    sourceName: "[테스트] 리워드 실패",
    sourceType: "mock_rewarded_fail",
    rewardType: "open_pass_minutes",
    rewardValue: 30,
    simulatedDurationSeconds: 3,
    failMode: "ad_error",
    priority: 2,
  },
  {
    sourceName: "[테스트] 노필(no-fill)",
    sourceType: "mock_rewarded_no_fill",
    rewardType: "open_pass_minutes",
    rewardValue: 30,
    simulatedDurationSeconds: 1,
    failMode: "no_fill",
    priority: 3,
  },
  {
    sourceName: "[테스트] 중도취소",
    sourceType: "mock_rewarded_cancel",
    rewardType: "open_pass_minutes",
    rewardValue: 30,
    simulatedDurationSeconds: 2,
    failMode: "user_cancelled",
    priority: 4,
  },
  {
    sourceName: "[테스트] 타임아웃",
    sourceType: "mock_rewarded_timeout",
    rewardType: "open_pass_minutes",
    rewardValue: 30,
    simulatedDurationSeconds: 8,
    failMode: "timeout",
    priority: 5,
  },
];

async function main() {
  // 1) 대상 PassPolicy 선정: testModeAllowed && isActive 인 정책 중 displayPriority 낮은(우선) 것
  let policy = await prisma.passPolicy.findFirst({
    where: { isActive: true, testModeAllowed: true, deletedAt: null },
    orderBy: [{ displayPriority: "asc" }, { id: "asc" }],
  });

  if (!policy) {
    console.log("⚠️ 활성 PassPolicy가 없어 테스트용 정책을 새로 생성합니다.");
    policy = await prisma.passPolicy.create({
      data: {
        name: "프리패스 (전체 운세 60분)",
        passType: "ad",
        durationMin: 60,
        dailyLimit: null,
        ctaText: "광고 보고 프리패스 받기",
        bonusPoint: 0,
        isActive: true,
        status: "active",
        description: "광고 시청으로 전체 운세를 60분간 잠금 해제하는 기본 프리패스 상품입니다.",
        scope: "fortune_today,fortune_tarot,fortune_saju,fortune_compatibility,fortune_face_palm,fortune_theme",
        happyMoneyPrice: null,
        adRewardEnabled: true,
        isFeatured: true,
        displayPriority: 0,
        uiCopy: JSON.stringify({
          lockCopy: "잠겨있어요. 광고 보고 60분간 전체 운세를 확인해보세요!",
          acquireCopy: "프리패스가 발급되었습니다! 60분간 전체 운세를 확인할 수 있어요.",
          expireCopy: "프리패스가 만료되었습니다. 다시 광고를 보고 잠금을 해제해보세요.",
        }),
        testModeAllowed: true,
      },
    });
    console.log(`✅ 새 PassPolicy 생성됨: id=${policy.id}, name=${policy.name}`);
  } else {
    console.log(`✅ 기존 PassPolicy 사용: id=${policy.id}, name=${policy.name}`);
  }

  for (const src of MOCK_SOURCES) {
    let adSource = await prisma.openPassAdSource.findFirst({
      where: { sourceType: src.sourceType, deletedAt: null },
    });

    if (!adSource) {
      adSource = await prisma.openPassAdSource.create({
        data: {
          sourceName: src.sourceName,
          sourceType: src.sourceType,
          networkName: "mock",
          adUnitId: null,
          placementId: null,
          rewardType: src.rewardType,
          rewardValue: src.rewardValue,
          cooldownSeconds: 0,
          dailyLimit: null,
          failoverEnabled: true,
          testModeEnabled: true,
          isActive: true,
          priority: src.priority,
          status: "active",
          simulatedDurationSeconds: src.simulatedDurationSeconds,
          failMode: src.failMode,
        },
      });
      console.log(`  ➕ 생성: ${adSource.sourceName} (id=${adSource.id})`);
    } else {
      adSource = await prisma.openPassAdSource.update({
        where: { id: adSource.id },
        data: {
          simulatedDurationSeconds: src.simulatedDurationSeconds,
          failMode: src.failMode,
          testModeEnabled: true,
          isActive: true,
        },
      });
      console.log(`  ♻️ 이미 존재(업데이트됨): ${adSource.sourceName} (id=${adSource.id})`);
    }

    // 2) 정책에 바인딩 (없으면 생성)
    const existingBinding = await prisma.openPassProductAdSource.findFirst({
      where: { passPolicyId: policy.id, adSourceId: adSource.id },
    });

    if (!existingBinding) {
      await prisma.openPassProductAdSource.create({
        data: {
          passPolicyId: policy.id,
          adSourceId: adSource.id,
          priority: src.priority,
          isPrimary: src.sourceType === "mock_rewarded_success",
          platform: "all",
          isActive: true,
        },
      });
      console.log(`    🔗 바인딩 생성: policy=${policy.id} <-> adSource=${adSource.id}`);
    } else {
      console.log(`    🔗 바인딩 이미 존재: policy=${policy.id} <-> adSource=${adSource.id}`);
    }
  }

  console.log("\n✅ 시드 완료.");
  console.log(`   대상 정책: id=${policy.id}, name="${policy.name}"`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
