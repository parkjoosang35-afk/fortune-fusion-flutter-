// 내 소원 목록 API — WishWallRepository.fetchMyWishes() 대응.
// [사용자 확정 원칙] 로그인 사용자 것만 반환. 반드시 authenticateRequest()로
// 결정된 userId만 사용하며, 쿼리로 전달된 userId는 존재하더라도 무시한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, requireUser, toWishDto, unauthorizedResponse, type WishRow } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const wishes = await prisma.wish.findMany({
      where: { userId: auth.userId, deletedAt: null },
      include: { user: { select: { nickname: true } } },
      orderBy: [{ createdAt: "desc" }],
    });

    const data = (wishes as unknown as WishRow[]).map((w) => toWishDto(w, auth.userId));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wishes/my] 실패:", e);
    return NextResponse.json(
      { success: false, error: "내 소원 목록을 불러오지 못했습니다." },
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
