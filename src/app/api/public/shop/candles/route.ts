// 상점 카탈로그 조회 API — bokjumeoni-plan §03 SERVER API `GET /shop/candles` 대응.
//
// itemType='candle'인 활성(isActive=true) ShopCatalogItem만 표시우선순위
// 순으로 반환한다. 비로그인 사용자도 카탈로그를 열람할 수 있어야 하므로
// (구매 전 미리보기) 인증을 요구하지 않는다.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, toShopCatalogDto } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const items = await prisma.shopCatalogItem.findMany({
      where: { itemType: "candle", isActive: true, deletedAt: null },
      orderBy: [{ displayPriority: "asc" }],
    });
    return NextResponse.json(
      { success: true, data: items.map(toShopCatalogDto) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/shop/candles] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상점 목록을 불러오지 못했습니다." },
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
