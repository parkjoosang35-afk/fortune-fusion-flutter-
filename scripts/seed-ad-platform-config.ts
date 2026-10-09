// [신통방통 관리자 통합 간소화 실행 지시서 - task 4 "광고관리 통합메뉴"]
// AdPlatformConfig 초기 시드 데이터(admob/adsense 2행) 생성 스크립트.
// 1회성 실행 스크립트이지만 결과(영구 데이터)는 유지한다 — 테스트 후 롤백하지 않음.
// 실행: npx tsx scripts/seed-ad-platform-config.ts
import { prisma } from "@/lib/db";

async function main() {
  // ── admob 행: isEnabled(노출 킬스위치)만 원격 제어. 실제 Ad Unit ID 전환은
  // 여전히 Flutter의 --dart-define=ADMOB_USE_REAL_IDS 빌드타임 플래그로만 허용한다.
  const admob = await prisma.adPlatformConfig.upsert({
    where: { platform: "admob" },
    update: {},
    create: {
      platform: "admob",
      isEnabled: true,
      publisherId: null,
      showPlaceholderWhenDisabled: true,
      surfaceConfigJson: null,
      formatConfigJson: null,
      note:
        "AdMob은 이 행의 isEnabled로 광고 노출 여부(킬스위치)만 원격 제어합니다. " +
        "실제 Ad Unit ID(배너/전면/보상형) 전환은 안전상 이 테이블이 아니라 " +
        "Flutter 빌드 시 --dart-define=ADMOB_USE_REAL_IDS=true 플래그로만 허용됩니다 " +
        "(무효 트래픽으로 인한 계정정지 위험 방지를 위한 의도적 설계).",
      updatedBy: "system-seed",
    },
  });

  // ── adsense 행: 퍼블리셔ID + 서비스별(surface) + 포맷별(format) 노출을
  // 전부 이 테이블이 담당한다(완전 원격 제어). 기존 web_ad_config.dart의
  // 컴파일타임 기본값과 동일한 값으로 초기화해 전환 시 동작이 바뀌지 않도록 한다.
  const adsense = await prisma.adPlatformConfig.upsert({
    where: { platform: "adsense" },
    update: {},
    create: {
      platform: "adsense",
      isEnabled: false,
      publisherId: null,
      showPlaceholderWhenDisabled: true,
      surfaceConfigJson: JSON.stringify({
        home: false,
        sajuRenewal: true,
        tarot: true,
        wishRoom: false,
        guinji: true,
        face: true,
        palm: true,
      }),
      formatConfigJson: JSON.stringify({
        banner: true,
        inPage: true,
        anchor: true,
        vignette: true,
      }),
      note:
        "AdSense는 publisherId + 서비스별(surface) + 포맷별(format) 노출을 " +
        "전부 이 행이 담당합니다(완전 원격 제어). Flutter AdRemoteConfigService가 " +
        "앱 시작 시 /api/public/ad-config로 조회해 WebAdConfig의 컴파일타임 " +
        "기본값을 런타임에 덮어씁니다(조회 실패 시 기존 기본값으로 안전 폴백). " +
        "isEnabled=false 및 publisherId=null인 초기 상태이므로 실 서비스 광고는 " +
        "아직 노출되지 않습니다 — 운영 적용 전 반드시 publisherId를 설정하세요.",
      updatedBy: "system-seed",
    },
  });

  console.log("✅ AdPlatformConfig 시드 완료:");
  console.log(JSON.stringify({ admob, adsense }, null, 2));
}

main()
  .catch((e) => {
    console.error("❌ 시드 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
