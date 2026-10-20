import { prisma } from '@/lib/db';

// 승인된 설정값 (대표 확정):
// - publisherId: ca-pub-4640621040048656 (ads.txt pub-4640621040048656와 일치)
// - 서비스 범위: 사주/타로/귀인지도/관상/손금 ON, 홈/소원방 OFF
// - 포맷: 배너/인페이지/비네트 ON, 앵커 OFF
const surfaceConfig = {
  home: false,
  sajuRenewal: true,
  tarot: true,
  wishRoom: false, // 정책상 영구 제외
  guinji: true,
  face: true,
  palm: true,
};
const formatConfig = {
  banner: true,
  inPage: true,
  anchor: false,
  vignette: true,
};

async function main() {
  const before = await prisma.adPlatformConfig.findUnique({ where: { platform: 'adsense' } });
  if (!before) {
    console.error('adsense 설정 행이 존재하지 않습니다.');
    process.exit(1);
  }
  console.log('BEFORE:', JSON.stringify(before, null, 2));

  const after = await prisma.adPlatformConfig.update({
    where: { platform: 'adsense' },
    data: {
      isEnabled: true,
      publisherId: 'ca-pub-4640621040048656',
      showPlaceholderWhenDisabled: true,
      surfaceConfigJson: JSON.stringify(surfaceConfig),
      formatConfigJson: JSON.stringify(formatConfig),
      updatedBy: 'cli-script-adsense-setup',
    },
  });
  console.log('AFTER:', JSON.stringify(after, null, 2));
}
main().finally(() => prisma.$disconnect());
