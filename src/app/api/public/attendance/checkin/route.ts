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
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

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
  // [버그 수정 — 대표 신고 "출석체크 안됨"] 이 라우트는 userId를 항상
  // 인증 토큰(requireUser)에서 가져오고 요청 본문의 값은 애초에 전혀
  // 참조하지 않는다. 그런데도 `await request.json()`을 무조건 실행해서,
  // 본문을 아예 보내지 않는 Flutter 클라이언트(AttendanceRepository.
  // checkIn() — http.post()에 body 파라미터 자체가 없음)가 호출하면
  // 빈 본문 파싱이 즉시 실패해 "요청 본문이 올바르지 않습니다"(400)로
  // 인증 체크보다도 먼저 막혀버린다 — 로그인 여부와 무관하게 출석체크가
  // 100% 실패하던 근본 원인. 본문이 비어 있거나 JSON이 아니어도 그냥
  // 무시하고 진행한다(파싱 결과를 애초에 쓰지 않으므로 안전).
  try {
    await request.json();
  } catch {
    // 본문이 없거나 JSON이 아니어도 무시 — 아래 로직은 body를 쓰지 않는다.
  }

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;

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

      // 3) streak_day에 맞는 보상 규칙 조회.
      // [2026 출석 연속보너스 재설계] 1~30일차는 "N일차 = N×10개"
      // 선형 보상표(attendance_reward_rules에 1~30 전부 등록됨)를 그대로
      // 따른다. 31일차 이후(연속출석을 계속 이어가는 경우)는 규칙 테이블에
      // 해당 streak_day가 없어 예전에는 point_policies.attendance의
      // 일반 폴백값(3개)으로 뚝 떨어졌는데, 30일째 300개를 받던 사용자가
      // 31일째에 3개로 급락하는 것은 보상 체계상 부자연스러운 "절벽" 현상이라
      // 판단해 — 최고 등록된 streak_day(현재 30일차=300개)의 보상을 계속
      // 유지(sustain)하도록 개선한다. 연속출석이 끊기면 §4의 리셋 로직에
      // 따라 어차피 1일차(10개)부터 다시 시작하므로 악용 소지는 없다.
      const rule = await tx.attendanceRewardRule.findFirst({
        where: { streakDay: streakCount, status: "active", deletedAt: null },
      });
      let rewardPoint = rule?.rewardPoint;
      if (rewardPoint == null) {
        const maxRule = await tx.attendanceRewardRule.findFirst({
          where: { status: "active", deletedAt: null },
          orderBy: { streakDay: "desc" },
        });
        if (maxRule && streakCount > maxRule.streakDay) {
          // 등록된 보상표의 마지막 날짜(예: 30일차)를 넘어서도 계속
          // 출석 중이라면, 마지막 날짜의 보상을 그대로 유지 지급한다.
          rewardPoint = maxRule.rewardPoint;
        } else {
          const fallbackPolicy = await tx.pointPolicy.findUnique({
            where: { sourceType: "attendance" },
          });
          // [복주머니 정책표 재정리 - 2026] 정책표 §3 "출석 체크 3개/1일 1회" 기준 폴백값.
          rewardPoint = fallbackPolicy?.amount ?? 3;
        }
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
