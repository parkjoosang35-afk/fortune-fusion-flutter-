// 공개(비인증) 복주머니 상품/확률표 조회 API — Flutter LuckyBagRepository.getProducts()/
// getProbabilities() 대응.
//
// [필터링 조건] 상품(luckybag_products): deletedAt=null, isActive=true, status='active'.
// 시즌(luckybag_seasons)이 연결된 상품은 현재시각이 시즌 기간(start_at~end_at) 내에 있을 때만 노출.
// 확률표(luckybag_reward_pools): deletedAt=null인 항목만, gradeId로 LuckybagGrade 조인.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Access-Control-Allow-Origin": "*",
};

// grade.rewardAmount/rewardRefId를 화면 표시용 rewardLabel 문자열로 변환.
async function buildRewardLabel(
  rewardType: string,
  rewardAmount: number | null,
  rewardRefId: number | null
): Promise<string> {
  if (rewardType === "none") return "다음 기회에";
  if (rewardType === "point") return `${(rewardAmount ?? 0).toLocaleString()}P`;
  if (rewardType === "giftcard_fragment") return "상품권 조각";
  if (rewardType === "amulet") {
    if (rewardRefId) {
      const item = await prisma.amuletItem.findUnique({ where: { id: rewardRefId } });
      if (item) return item.name;
    }
    return "랜덤 부적";
  }
  return rewardType;
}

export async function GET(_request: NextRequest) {
  const now = new Date();

  const products = await prisma.luckybagProduct.findMany({
    where: { deletedAt: null, isActive: true, status: "active" },
    include: { season: true },
    orderBy: { id: "asc" },
  });

  const visibleProducts = products.filter((p) => {
    if (!p.season) return true;
    return now >= p.season.startAt && now <= p.season.endAt;
  });

  const productIds = visibleProducts.map((p) => p.id);
  const pools = await prisma.luckybagRewardPool.findMany({
    where: { luckybagProductId: { in: productIds }, deletedAt: null, status: "active" },
    include: { grade: true },
    orderBy: [{ luckybagProductId: "asc" }, { id: "asc" }],
  });

  const poolsByProduct = new Map<number, typeof pools>();
  for (const pool of pools) {
    const list = poolsByProduct.get(pool.luckybagProductId) ?? [];
    list.push(pool);
    poolsByProduct.set(pool.luckybagProductId, list);
  }

  const productPayload = visibleProducts.map((p) => ({
    id: p.id,
    name: p.name,
    pricePoint: p.pricePoint,
    imageUrl: p.imageUrl,
    seasonName: p.season?.name ?? null,
  }));

  const probabilitiesPayload: Record<string, unknown[]> = {};
  for (const [productId, productPools] of poolsByProduct.entries()) {
    probabilitiesPayload[String(productId)] = await Promise.all(
      productPools.map(async (pool) => ({
        id: pool.id,
        gradeCode: pool.grade.code,
        gradeName: pool.grade.name,
        rewardType: pool.rewardType,
        rewardLabel: await buildRewardLabel(pool.rewardType, pool.rewardAmount, pool.rewardRefId),
        rewardAmount: pool.rewardAmount,
        probability: pool.probability,
      }))
    );
  }

  return NextResponse.json(
    {
      success: true,
      data: { products: productPayload, probabilities: probabilitiesPayload },
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
