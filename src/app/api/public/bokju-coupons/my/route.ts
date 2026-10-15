// [복주머니 마케팅 쿠폰] GET /api/public/bokju-coupons/my
// 내가 등록(redeem)에 성공한 쿠폰 이력 조회. Flutter 앱의 "내 쿠폰함/적립 이력" 화면용.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse, CORS_HEADERS } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const redemptions = await prisma.bokjuCouponRedemption.findMany({
      where: { userId: auth.userId, result: "SUCCESS" },
      include: { campaign: true },
      orderBy: { createdAt: "desc" },
      take: 100,
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          redemptions: redemptions.map((r) => ({
            id: r.id,
            campaignTitle: r.campaign?.title ?? null,
            grantedAmount: r.grantedAmount ?? 0,
            balanceAfter: r.balanceAfter ?? 0,
            redeemedAt: r.createdAt.toISOString(),
          })),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/bokju-coupons/my] 실패:", e);
    return NextResponse.json(
      { success: false, error: "이력 조회 중 오류가 발생했습니다." },
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
