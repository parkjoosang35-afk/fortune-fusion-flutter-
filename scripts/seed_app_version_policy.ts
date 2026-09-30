// [DEV-2026-001 작업3-5-1] app-version API가 참조하는 system_settings
// 초기값을 심는다. 운영 서버에 아직 실제 APK 배포 채널이 없으므로(작업1
// 진단 결과 ⑤), latest=min=1로 시작해 강제 업데이트가 즉시 발동하지
// 않도록 안전한 기본값을 사용한다. Android 배포 채널이 실제로 열리면
// admin_web의 "시스템 설정" 화면에서 latest_version_code_android를
// 올리는 것만으로 신규 버전 안내가 가능해진다.
import { prisma } from "../src/lib/db";

const DEFAULTS: Array<{ key: string; value: unknown; description: string }> = [
  {
    key: "latest_version_code_android",
    value: 1,
    description: "[DEV-2026-001] Android 최신 배포 versionCode(정수). 앱 버전체크 API(/api/public/app-version)가 참조.",
  },
  {
    key: "min_version_code_android",
    value: 1,
    description: "[DEV-2026-001] Android 강제 업데이트 기준 versionCode(정수, 이 미만이면 서비스 차단). 앱 버전체크 API가 참조.",
  },
  {
    key: "update_url_android",
    value: "https://play.google.com/store/apps",
    description: "[DEV-2026-001] 강제 업데이트 팝업의 '업데이트' 버튼이 여는 URL(Android).",
  },
  {
    key: "update_notice",
    value: "",
    description: "[DEV-2026-001] 강제 업데이트 팝업에 표시할 추가 안내 문구(선택, 빈 문자열이면 기본 문구만 표시).",
  },
];

async function main() {
  for (const item of DEFAULTS) {
    const existing = await prisma.systemSetting.findUnique({ where: { key: item.key } });
    if (existing) {
      console.log(`[skip] ${item.key} 이미 존재 (value=${existing.value}) — 덮어쓰지 않음`);
      continue;
    }
    await prisma.systemSetting.create({
      data: {
        key: item.key,
        value: JSON.stringify(item.value),
        description: item.description,
        status: "active",
        createdBy: "system(DEV-2026-001 seed script)",
      },
    });
    console.log(`[created] ${item.key} = ${JSON.stringify(item.value)}`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
