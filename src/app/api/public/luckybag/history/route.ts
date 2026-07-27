// 공개(비인증) 복주머니 개봉 이력 조회 API — Flutter LuckyBagRepository.getHistory()/
// getRewardSummary() 대응.
//
// [조회 대상] luckybag_open_logs를 userId 기준으로 createdAt desc 정렬 조회, 최근 100건.
// luckybag_products, luckybag_reward_pools.grade를 include하여 화면 표시에 필요한
// 상품명/등급명을 함께 반환. reward_result(JSON 문자열)를 파싱해 rewardType/rewardLabel/
// rewardAmount를 꺼낸다(개봉 시점의 스냅샷을 그대로 사용 — 이후 상품/확률표 변경과 무관).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Access-Control-Allow-Origin": "*",
};

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? 1);

  const logs = await prisma.luckybagOpenLog.findMany({
    where: { userId, deletedAt: null },
    include: {
      luckybagProduct: true,
      rewardPool: { include: { grade: true } },
    },
    orderBy: { createdAt: "desc" },
    take: 100,
  });

  const items = logs.map((log) => {
    let parsed: {
      gradeCode?: string;
      gradeName?: string;
      rewardType?: string;
      rewardLabel?: string;
      rewardAmount?: number | null;
    } = {};
    try {
      parsed = JSON.parse(log.rewardResult);
    } catch {
      parsed = {};
    }

    return {
      id: log.id,
      product: {
        id: log.luckybagProduct.id,
        name: log.luckybagProduct.name,
        pricePoint: log.luckybagProduct.pricePoint,
        imageUrl: log.luckybagProduct.imageUrl,
      },
      gradeCode: parsed.gradeCode ?? log.rewardPool.grade.code,
      gradeName: parsed.gradeName ?? log.rewardPool.grade.name,
      rewardType: parsed.rewardType ?? log.rewardPool.rewardType,
      rewardLabel: parsed.rewardLabel ?? "다음 기회에",
      rewardAmount: parsed.rewardAmount ?? null,
      openedAt: log.createdAt.toISOString(),
    };
  });

  // 등급별 집계(홈/이력 화면의 "전적 요약" 카드용) — 클라이언트에서 별도 계산하지 않도록
  // 서버에서 미리 합산해 제공.
  const summaryMap = new Map<string, { gradeCode: string; gradeName: string; count: number; totalPointReward: number }>();
  for (const item of items) {
    const key = item.gradeCode;
    const entry = summaryMap.get(key) ?? {
      gradeCode: item.gradeCode,
      gradeName: item.gradeName,
      count: 0,
      totalPointReward: 0,
    };
    entry.count += 1;
    if (item.rewardType === "point" && typeof item.rewardAmount === "number") {
      entry.totalPointReward += item.rewardAmount;
    }
    summaryMap.set(key, entry);
  }

  return NextResponse.json(
    {
      success: true,
      data: {
        items,
        summary: Array.from(summaryMap.values()),
      },
    },
    { headers: CORS_HEADERS }
  );
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
