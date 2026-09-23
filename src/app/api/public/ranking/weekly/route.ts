// 공개(비인증) 주간 포인트 랭킹 조회 API — RankingRepository.getWeeklyRanking() 대응.
//
// [설계결정] ranking_snapshots는 이미 주 단위(period, 예: "2026-W30")로 미리 계산되어
// 시딩되어 있다. 가장 최신 period를 자동으로 찾아 rankingType="point" 스냅샷을 그대로
// 반환한다(Mock의 "myPoints로 임의 순위 삽입" 방식 대신, 실제 저장된 점수/순위를 사용).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  // [D-04류 결함수정] "내 순위 표시"는 body/query의 userId가 아닌 JWT로만 판단한다.
  // 랭킹 목록 자체는 비로그인도 열람 가능해야 하므로(공개 정보) requireUser()가 null이어도
  // 계속 진행하되, isMe 판별에는 반드시 인증된 userId만 사용한다(위조 불가).
  const auth = await requireUser(request);
  const userId = auth?.userId ?? null;

  try {
    const latestPeriodRow = await prisma.rankingSnapshot.findFirst({
      where: { rankingType: "point", status: "active" },
      orderBy: { period: "desc" },
      select: { period: true },
    });
    if (!latestPeriodRow) {
      return NextResponse.json({ success: true, data: [] }, { headers: CORS_HEADERS });
    }

    const snapshots = await prisma.rankingSnapshot.findMany({
      where: {
        rankingType: "point",
        period: latestPeriodRow.period,
        status: "active",
      },
      include: { user: true },
      orderBy: { rank: "asc" },
    });

    const data = snapshots.map((s) => ({
      rank: s.rank,
      nickname: s.user.nickname,
      points: s.score,
      isMe: s.userId === userId,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/ranking/weekly] 실패:", e);
    return NextResponse.json(
      { success: false, error: "랭킹을 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
