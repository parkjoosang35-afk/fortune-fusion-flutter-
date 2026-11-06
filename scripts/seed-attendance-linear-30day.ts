// [마이페이지 리뉴얼 — 출석 연속보너스 재설계] 사용자 요청에 따라
// "1일차~30일차 연속출석, N일차 = N×10개, 30일차(최대) = 300개"
// 선형 보상표로 attendance_reward_rules 전체(1~30일차)를 채운다.
//
// 배경: 기존에는 1/3/7/14/21/30일차 6개만 등록되어 있었고 금액도 선형이
// 아니었다(10/20/50/100/150/300). 사용자가 명시적으로 "1일차 10개, 2일차
// 20개 ... 30일차 300개"를 요청했고, 연속출석이 끊기면 처음(10개)부터
// 다시 시작하도록 요청했다 — 이 reset 로직은 이미
// /api/public/attendance/checkin/route.ts 가 "어제 출석 기록 없으면
// streakCount=1로 리셋"하는 방식으로 구현되어 있으므로 코드 변경은
// 필요 없고, streak_day 1~30 전부에 대해 정확히 일치하는 보상규칙 행만
// 채워주면 된다(규칙이 없는 날은 point_policies.attendance 폴백 3P로
// 떨어지므로, 반드시 1~30 전부를 채워야 한다).
//
// 실행: cd /home/user/admin_web && npx tsx scripts/seed-attendance-linear-30day.ts
// idempotent: streak_day UNIQUE 제약을 이용해 upsert로 동작 — 여러 번 실행해도 안전.
import "dotenv/config";
import { prisma } from "@/lib/db";

async function main() {
  console.log("[seed-attendance-linear-30day] 1~30일차 선형 보상표(N×10) upsert 시작...");

  let created = 0;
  let updated = 0;

  for (let day = 1; day <= 30; day++) {
    const rewardPoint = day * 10; // 1일차=10, 2일차=20, ... 30일차=300

    const existing = await prisma.attendanceRewardRule.findUnique({
      where: { streakDay: day },
    });

    if (existing) {
      if (existing.rewardPoint !== rewardPoint || existing.status !== "active" || existing.deletedAt !== null) {
        await prisma.attendanceRewardRule.update({
          where: { streakDay: day },
          data: {
            rewardPoint,
            status: "active",
            deletedAt: null,
            updatedBy: "system:seed-attendance-linear-30day",
          },
        });
        updated++;
      }
    } else {
      await prisma.attendanceRewardRule.create({
        data: {
          streakDay: day,
          rewardPoint,
          status: "active",
          createdBy: "system:seed-attendance-linear-30day",
          updatedBy: "system:seed-attendance-linear-30day",
        },
      });
      created++;
    }
  }

  console.log(`[seed-attendance-linear-30day] 완료 — 생성 ${created}건, 갱신 ${updated}건 (총 30일차 보상표).`);

  const all = await prisma.attendanceRewardRule.findMany({
    where: { deletedAt: null, status: "active" },
    orderBy: { streakDay: "asc" },
  });
  console.log(
    "[seed-attendance-linear-30day] 최종 상태:",
    all.map((r) => `${r.streakDay}일=${r.rewardPoint}개`).join(", ")
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
