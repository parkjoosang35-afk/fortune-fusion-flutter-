// 공개(비인증) 부적 상점 목록 조회 API — Flutter AmuletRepository.getShopItems() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest) {
  try {
    const items = await prisma.amuletItem.findMany({
      where: { status: "active", deletedAt: null },
      include: { grade: true },
      orderBy: [{ gradeId: "asc" }, { id: "asc" }],
    });

    const data = items.map((i) => ({
      id: `am_${i.id}`,
      name: i.name,
      gradeCode: i.grade.code,
      gradeName: i.grade.name,
      effectDescription: i.effectDescription,
      imageUrl: i.imageUrl,
      isAiGenerated: i.isAiGenerated,
      pricePoint: i.pricePoint,
      isLimited: i.isLimited,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/amulets/shop] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 상점 목록을 불러오지 못했습니다." },
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
