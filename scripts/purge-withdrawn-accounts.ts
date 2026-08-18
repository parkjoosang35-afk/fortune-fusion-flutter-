// 6-7-4-B-4 Task #2: 탈퇴 회원 데이터 파기 배치 실행 스크립트
//
// `UserWithdrawalLog.dataPurgeScheduledAt`(탈퇴일+30일)이 도래했지만 아직
// 파기되지 않은(`dataPurgedAt IS NULL`) 계정을 찾아 src/lib/account-purge.ts의
// purgeUserData()로 실제 비식별화+하드삭제를 수행한다.
//
// 실행(수동): cd /home/user/admin_web && npx tsx scripts/purge-withdrawn-accounts.ts
// 실행(cron 예시, 매일 새벽 4시): 0 4 * * * cd /home/user/admin_web && npx tsx scripts/purge-withdrawn-accounts.ts >> logs/purge.log 2>&1
//
// [주의] 이 스크립트는 cron 등록 자체를 수행하지 않는다(샌드박스 환경에
// cron 데몬이 없거나 운영 서버 구성이 배포 단계에서 결정되므로, 실행 방식
// 선택은 배포 담당자의 몫으로 남긴다 — 04A/05 범위를 벗어나는 인프라 결정은
// 임의로 하지 않는다는 원칙 준수).
import "dotenv/config";
import { prisma } from "@/lib/db";
import { purgeDueAccounts } from "@/lib/account-purge";

async function main() {
  console.log(`[purge-withdrawn-accounts] 시작: ${new Date().toISOString()}`);

  const summaries = await purgeDueAccounts();

  if (summaries.length === 0) {
    console.log("파기 대상 계정 없음.");
  } else {
    for (const s of summaries) {
      if (s.skipped) {
        console.log(`- userId=${s.userId}: 건너뜀 (${s.reason})`);
      } else {
        console.log(`- userId=${s.userId}: 파기 완료`, s.deletedCounts);
      }
    }
  }

  const purgedCount = summaries.filter((s) => !s.skipped).length;
  console.log(
    `[purge-withdrawn-accounts] 종료: 대상 ${summaries.length}건 중 ${purgedCount}건 파기 완료.`
  );

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error("[purge-withdrawn-accounts] 실패:", e);
  process.exit(1);
});
