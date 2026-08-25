// 보물함(인벤토리) 조회 API — bokjumeoni-plan §03 SERVER API `GET /inventory` 대응.
//
// 로그인 사용자가 상점에서 구매한 UserInventoryItem 전체를 최신 구매순으로
// 반환한다. 만료(expiresAt 경과) 여부는 삭제/필터링하지 않고 isExpired 플래그로만
// 노출한다 — "보물함에서 만료된 부적도 이력으로 확인 가능해야 한다"는 원칙
// (구매 기록/원장 유지 절대원칙과 동일 맥락).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, toInventoryItemDto } from "../shop/_shared";
import { requireUser, unauthorizedResponse } from "../wishes/_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const items = await prisma.userInventoryItem.findMany({
      where: { userId: auth.userId },
      include: { catalogItem: true },
      orderBy: [{ createdAt: "desc" }],
    });

    return NextResponse.json(
      { success: true, data: items.map(toInventoryItemDto) },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/inventory] 실패:", e);
    return NextResponse.json(
      { success: false, error: "보물함 목록을 불러오지 못했습니다." },
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
