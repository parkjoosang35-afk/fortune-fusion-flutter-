// 공개(비인증) 결제 내역 조회 API — SubscriptionRepository.getPaymentHistory() 대응.
// Flutter PaymentModel.orderType은 문자열 그대로 매핑하되, 이번 화면은 구독 결제
// 내역만 다루므로 orderType='subscription'으로 필터한다(giftcard/amulet/luckybag
// 결제건은 payments 테이블에 함께 존재하지만 이 화면 범위 밖).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const payments = await prisma.payment.findMany({
      where: { userId, orderType: "subscription" },
      orderBy: { createdAt: "desc" },
    });
    const data = payments.map((p) => ({
      id: `pay_${p.id}`,
      orderType: p.orderType,
      amount: p.amount,
      pgProvider: p.pgProvider,
      status: p.status,
      createdAt: p.createdAt.toISOString(),
    }));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/subscription/payments] 실패:", e);
    return NextResponse.json(
      { success: false, error: "결제 내역을 불러오지 못했습니다." },
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
