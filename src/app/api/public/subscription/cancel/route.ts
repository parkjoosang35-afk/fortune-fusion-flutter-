// 공개(비인증) 구독 취소 API — SubscriptionRepository.cancel() 대응.
// 04A K-4 status(active/cancelled/expired/past_due) 중 cancelled로 전환만 수행한다.
// (환불(K-2 payment_refunds)은 이번 1차 범위 밖 - Mock 단계와 동일 원칙)
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseBenefits(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

export async function POST(request: NextRequest) {
  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const current = await prisma.userSubscription.findFirst({
      where: { userId, status: "active", deletedAt: null },
    });
    if (!current) {
      return NextResponse.json(
        { success: false, error: "구독 중인 플랜이 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    const updated = await prisma.userSubscription.update({
      where: { id: current.id },
      data: { status: "cancelled" },
      include: { plan: true },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `sub_${updated.id}`,
          plan: {
            id: `plan_${updated.plan.id}`,
            name: updated.plan.name,
            price: updated.plan.price,
            period: updated.plan.period,
            benefits: parseBenefits(updated.plan.benefits),
            isActive: updated.plan.isActive,
          },
          status: updated.status,
          startedAt: updated.startedAt.toISOString(),
          currentPeriodEnd: updated.currentPeriodEnd.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/subscription/cancel] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구독 취소 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
