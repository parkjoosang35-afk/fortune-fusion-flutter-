// 공개(비인증) 출석 체크인 API — Flutter AttendanceRepository.checkIn() 대응.
//
// [설계] attendance_reward_rules(streak_day 기준 보상표)를 조회해 연속출석일에 맞는
// reward_point를 지급한다(예: 1일차 10P, 3일차 20P, 7일차 50P...). 규칙이 없는
// streak_day는 point_policies.attendance(기본 10P)로 폴백한다.
// 1일 1회 원칙: 같은 날(KST 기준) 이미 체크인했으면 재차감 없이 기존 결과를 그대로 반환한다
// (fortune/daily route.ts의 멱등성 패턴과 동일).
// incrementMissionProgress(actionType="attendance")를 호출해 관련 미션 진행률도 갱신한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { incrementMissionProgress } from "@/lib/mission-progress";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function todayRangeUtcKST(): { start: Date; end: Date } {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  const startKst = new Date(Date.UTC(y, m, d, 0, 0, 0));
  const endKst = new Date(Date.UTC(y, m, d + 1, 0, 0, 0));
  const start = new Date(startKst.getTime() - 9 * 60 * 60 * 1000);
  const end = new Date(endKst.getTime() - 9 * 60 * 60 * 1000);
  return { start, end };
}

function yesterdayRangeUtcKST(): { start: Date; end: Date } {
  const { start, end } = todayRangeUtcKST();
  return {
    start: new Date(start.getTime() - 24 * 60 * 60 * 1000),
    end: new Date(end.getTime() - 24 * 60 * 60 * 1000),
  };
}

export async function POST(request: NextRequest) {
  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const { start: todayStart, end: todayEnd } = todayRangeUtcKST();
      const { start: yestStart, end: yestEnd } = yesterdayRangeUtcKST();

      // 1) 오늘 이미 체크인했으면 재차감 없이 그대로 반환(멱등성)
      const existingToday = await tx.attendance.findFirst({
        where: { userId, attendDate: { gte: todayStart, lt: todayEnd }, deletedAt: null },
      });
      if (existingToday) {
        const wallet = await tx.wallet.findFirst({
          where: { userId, currencyType: "POINT", deletedAt: null },
        });
        return {
          attendance: existingToday,
          alreadyChecked: true,
          rewardPoint: existingToday.rewardPoint,
          balanceAfter: wallet?.balance ?? null,
        };
      }

      // 2) 어제 출석 기록이 있으면 streak 이어가기, 없으면 1로 리셋
      const yesterdayAttendance = await tx.attendance.findFirst({
        where: { userId, attendDate: { gte: yestStart, lt: yestEnd }, deletedAt: null },
      });
      const streakCount = (yesterdayAttendance?.streakCount ?? 0) + 1;

      // 3) streak_day에 맞는 보상 규칙 조회, 없으면 point_policies.attendance로 폴백
      const rule = await tx.attendanceRewardRule.findFirst({
        where: { streakDay: streakCount, status: "active", deletedAt: null },
      });
      let rewardPoint = rule?.rewardPoint;
      if (rewardPoint == null) {
        const fallbackPolicy = await tx.pointPolicy.findUnique({
          where: { sourceType: "attendance" },
        });
        rewardPoint = fallbackPolicy?.amount ?? 10;
      }

      const attendance = await tx.attendance.create({
        data: {
          userId,
          attendDate: new Date(),
          streakCount,
          rewardPoint,
          bonusItemType: rule?.bonusItemType ?? null,
          bonusItemId: rule?.bonusItemId ?? null,
        },
      });

      // 4) 지갑 적립 + 원장 기록
      let wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) {
        wallet = await tx.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
      }
      const balanceAfter = wallet.balance + rewardPoint;
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: balanceAfter, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: rewardPoint,
          type: "earn",
          sourceType: "attendance",
          sourceId: attendance.id,
          balanceAfter,
          memo: `출석 체크인 (${streakCount}일차)`,
        },
      });

      // 5) 관련 미션 진행률 갱신(예: "매일 출석하기" 등 actionType=attendance 미션)
      await incrementMissionProgress(tx, userId, "attendance");

      return { attendance, alreadyChecked: false, rewardPoint, balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          streak: outcome.attendance.streakCount,
          rewardPoint: outcome.rewardPoint,
          balanceAfter: outcome.balanceAfter,
          alreadyChecked: outcome.alreadyChecked,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/attendance/checkin] 실패:", e);
    return NextResponse.json(
      { success: false, error: "출석 체크인 처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
