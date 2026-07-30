// 공개(비인증) 출석 현황 조회 API — Flutter AttendanceRepository.getStatus() 대응.
// 최근 attendance 레코드로 streak(연속일수)와 오늘 체크 여부를 계산해 반환.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function todayRangeUtcKST(): { start: Date; end: Date; key: string } {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  const startKst = new Date(Date.UTC(y, m, d, 0, 0, 0));
  const endKst = new Date(Date.UTC(y, m, d + 1, 0, 0, 0));
  const start = new Date(startKst.getTime() - 9 * 60 * 60 * 1000);
  const end = new Date(endKst.getTime() - 9 * 60 * 60 * 1000);
  const key = `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  return { start, end, key };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const { start, end } = todayRangeUtcKST();

    const latest = await prisma.attendance.findFirst({
      where: { userId, deletedAt: null },
      orderBy: { attendDate: "desc" },
    });

    const checkedToday = latest
      ? latest.attendDate >= start && latest.attendDate < end
      : false;

    return NextResponse.json(
      {
        success: true,
        data: {
          streak: latest?.streakCount ?? 0,
          checkedToday,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/attendance/status] 실패:", e);
    return NextResponse.json(
      { success: false, error: "출석 현황을 불러오지 못했습니다." },
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
