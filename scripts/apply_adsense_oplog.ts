import { prisma } from '@/lib/db';

async function main() {
  const row = await prisma.adPlatformConfig.findUnique({ where: { platform: 'adsense' } });
  if (!row) { console.error('not found'); process.exit(1); }
  await prisma.operationLog.create({
    data: {
      actorType: 'admin',
      actorId: null,
      action: 'update',
      targetType: 'ad_platform_config',
      targetId: row.id,
      before: JSON.stringify({ isEnabled: false, publisherId: null }),
      after: JSON.stringify({ isEnabled: row.isEnabled, publisherId: row.publisherId, surfaceConfigJson: row.surfaceConfigJson, formatConfigJson: row.formatConfigJson }),
    },
  });
  console.log('operation log created');
}
main().finally(() => prisma.$disconnect());
