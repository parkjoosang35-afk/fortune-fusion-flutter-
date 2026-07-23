// 05_Admin_System_Design.md §3.11 "시스템 설정" — 3차(마지막) 소단위: 통계 스냅샷 관리
// 04A O-5 statistics_snapshots 시딩 데이터. metric_code별로 최근 14일간의
// 일별 배치 실행 결과(value JSON)를 생성하여 "배치 실행 상태 확인" 화면에서
// 최신 실행 여부/누락일 등을 확인할 수 있도록 구성한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

const METRICS: { code: string; label: string; genValue: (dayIdx: number) => Record<string, unknown> }[] = [
  {
    code: "dau",
    label: "일간 활성 사용자",
    genValue: (dayIdx) => ({ count: 1200 + ((dayIdx * 37) % 400), unit: "users" }),
  },
  {
    code: "point_issued_daily",
    label: "일간 포인트 지급량",
    genValue: (dayIdx) => ({ total: 50000 + ((dayIdx * 913) % 20000), unit: "points" }),
  },
  {
    code: "revenue_daily",
    label: "일간 결제 매출",
    genValue: (dayIdx) => ({ amount: 800000 + ((dayIdx * 12345) % 300000), currency: "KRW" }),
  },
  {
    code: "new_signup_daily",
    label: "일간 신규 가입",
    genValue: (dayIdx) => ({ count: 30 + ((dayIdx * 7) % 50), unit: "users" }),
  },
];

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

async function main() {
  const existing = await prisma.statisticsSnapshot.count();
  if (existing > 0) {
    console.log(`이미 통계 스냅샷 ${existing}건이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const today = new Date();
  const snapshotData: {
    metricCode: string;
    period: string;
    value: string;
    createdAt: Date;
  }[] = [];

  METRICS.forEach((metric) => {
    for (let dayIdx = 0; dayIdx < 14; dayIdx++) {
      // 최근 2일(dayIdx 0,1)은 배치 지연 시나리오를 위해 일부러 누락시킨다.
      // (dau의 dayIdx=0만 누락 → "오늘자 배치 미실행" 상태를 재현)
      if (metric.code === "dau" && dayIdx === 0) continue;

      const targetDate = new Date(today.getTime() - dayIdx * 24 * 60 * 60 * 1000);
      snapshotData.push({
        metricCode: metric.code,
        period: formatDate(targetDate),
        value: JSON.stringify(metric.genValue(dayIdx)),
        createdAt: new Date(targetDate.getTime() + 1000 * 60 * 5), // 자정+5분에 배치 실행됨
      });
    }
  });

  await prisma.statisticsSnapshot.createMany({
    data: snapshotData.map((s) => ({ ...s, createdBy: "system", updatedBy: "system" })),
  });
  console.log(`통계 스냅샷(statistics_snapshots) ${snapshotData.length}건 시딩 완료.`);
  console.log("(참고) dau의 오늘자(dayIdx=0) 스냅샷은 의도적으로 누락시켜 배치 미실행 상태를 재현함.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
