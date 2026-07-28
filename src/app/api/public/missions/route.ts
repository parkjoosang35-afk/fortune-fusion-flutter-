// 공개(비인증) 미션 목록 + 사용자별 진행률 조회 API — Flutter MissionRepository.getMissions() 대응.
//
// [Phase5 - 게임화 최소연동] 지금까지 Flutter는 5개 하드코딩 Mock 미션으로만 동작했고,
// admin_web에는 진행률을 조회할 공개 API 자체가 없었다. 이 라우트를 신설하여 실제
// missions(마스터) + user_missions(진행현황)를 조합해 반환한다.
//
// [진행률 갱신 방식] 이 API는 조회 전용이며, 실제 진행률 갱신은
// wallet/send(복 나누기)·fortune/daily(오늘의 운세 확인) 등 실제 행동이 발생하는
// API 라우트에서 incrementMissionProgress()를 호출해 처리한다(src/lib/mission-progress.ts).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

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
    const missions = await prisma.mission.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ periodType: "asc" }, { id: "asc" }],
    });

    const userMissions = await prisma.userMission.findMany({
      where: { userId, missionId: { in: missions.map((m) => m.id) } },
    });
    const progressByMissionId = new Map(userMissions.map((um) => [um.missionId, um]));

    const data = missions.map((m) => {
      const um = progressByMissionId.get(m.id);
      return {
        id: `m_${m.id}`,
        title: m.title,
        description: `${m.title} (목표 ${m.targetCount}회)`,
        rewardPoints: m.rewardPoint,
        period: m.periodType, // daily/weekly/achievement
        progressCount: um?.progressCount ?? 0,
        targetCount: m.targetCount,
        // claimed까지 되어야 화면에서 "완료"로 표시(보상 미수령 completed는 진행중과 동일 취급하지 않음:
        // 이번 최소연동에서는 완료 즉시 자동 claim되므로 completed 상태가 남는 경우는 드물다)
        isCompleted: um?.status === "completed" || um?.status === "claimed",
      };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/missions] 실패:", e);
    return NextResponse.json(
      { success: false, error: "미션 목록을 불러오지 못했습니다." },
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
