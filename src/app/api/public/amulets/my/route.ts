// 공개(비인증) 내 부적 보유 목록 조회 API — Flutter AmuletRepository.getMyAmulets() 대응.
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
    const myAmulets = await prisma.userAmulet.findMany({
      where: { userId, deletedAt: null },
      include: { amuletItem: { include: { grade: true } } },
      orderBy: { acquiredAt: "desc" },
    });

    const data = myAmulets.map((ua) => ({
      id: `ua_${ua.id}`,
      itemId: `am_${ua.amuletItemId}`,
      itemName: ua.amuletItem.name,
      gradeCode: ua.amuletItem.grade.code,
      gradeName: ua.amuletItem.grade.name,
      effectDescription: ua.amuletItem.effectDescription,
      imageUrl: ua.amuletItem.imageUrl,
      status: ua.status, // held/used/expired/gifted
      acquiredAt: ua.acquiredAt.toISOString(),
      expiresAt: ua.expiresAt?.toISOString() ?? null,
      sourceType: ua.sourceType,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/amulets/my] 실패:", e);
    return NextResponse.json(
      { success: false, error: "보유 부적 목록을 불러오지 못했습니다." },
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
