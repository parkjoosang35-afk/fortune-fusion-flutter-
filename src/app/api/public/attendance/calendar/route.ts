// 공개(비인증) 출석 달력 조회 API — Flutter 출석체크 화면(달력 UI) 대응.
//
// [배경] 기존 /api/public/attendance/status는 "streak/오늘체크여부"만 반환해
// 달력에 "이번 달 중 어느 날짜에 출석했는지"를 표시할 수 없었다. 이 엔드포인트는
// 요청한 연/월(기본값: 이번 달, KST 기준) 동안의 출석 날짜 목록과, 관리자가
// attendance_reward_rules에 등록한 마일스톤 보상표(1/3/7/14/21/30일차 등)를
// 함께 내려준다 — 30일 달력 + 보상 트랙 UI를 한 번의 호출로 그릴 수 있게 한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function kstDateKey(d: Date): string {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = kst.getUTCMonth() + 1;
  const day = kst.getUTCDate();
  return `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function todayRangeUtcKST(): { start: Date; end: Date } {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  const startKst = new Date(Date.UTC(y, m, d, 0, 0, 0));
  const endKst = new Date(Date.UTC(y, m, d + 1, 0, 0, 0));
  return {
    start: new Date(startKst.getTime() - 9 * 60 * 60 * 1000),
    end: new Date(endKst.getTime() - 9 * 60 * 60 * 1000),
  };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const year = Number(searchParams.get("year") ?? kstNow.getUTCFullYear());
  const month = Number(searchParams.get("month") ?? kstNow.getUTCMonth() + 1); // 1~12

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 요청된 KST 연/월의 [1일 00:00, 다음달 1일 00:00) 구간을 UTC로 환산.
    const monthStartKst = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0));
    const monthEndKst = new Date(Date.UTC(year, month, 1, 0, 0, 0));
    const monthStart = new Date(monthStartKst.getTime() - 9 * 60 * 60 * 1000);
    const monthEnd = new Date(monthEndKst.getTime() - 9 * 60 * 60 * 1000);

    const [monthAttendances, latest, rules] = await Promise.all([
      prisma.attendance.findMany({
        where: {
          userId,
          deletedAt: null,
          attendDate: { gte: monthStart, lt: monthEnd },
        },
        orderBy: { attendDate: "asc" },
      }),
      prisma.attendance.findFirst({
        where: { userId, deletedAt: null },
        orderBy: { attendDate: "desc" },
      }),
      prisma.attendanceRewardRule.findMany({
        where: { status: "active", deletedAt: null },
        orderBy: { streakDay: "asc" },
      }),
    ]);

    const { start: todayStart, end: todayEnd } = todayRangeUtcKST();
    const checkedToday = latest
      ? latest.attendDate >= todayStart && latest.attendDate < todayEnd
      : false;

    const attendedDates = monthAttendances.map((a) => ({
      date: kstDateKey(a.attendDate),
      rewardPoint: a.rewardPoint,
      streakCount: a.streakCount,
    }));

    const milestones = rules.map((r) => ({
      streakDay: r.streakDay,
      rewardPoint: r.rewardPoint,
    }));

    return NextResponse.json(
      {
        success: true,
        data: {
          year,
          month,
          streak: latest?.streakCount ?? 0,
          checkedToday,
          attendedDates,
          milestones,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/attendance/calendar] 실패:", e);
    return NextResponse.json(
      { success: false, error: "출석 달력 정보를 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
