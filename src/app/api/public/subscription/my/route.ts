// 공개(비인증) 내 구독 현황 조회 API — SubscriptionRepository.getMySubscription() 대응.
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

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const sub = await prisma.userSubscription.findFirst({
      where: { userId, deletedAt: null },
      include: { plan: true },
      orderBy: { createdAt: "desc" },
    });
    if (!sub) {
      return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
    }
    return NextResponse.json(
      {
        success: true,
        data: {
          id: `sub_${sub.id}`,
          plan: {
            id: `plan_${sub.plan.id}`,
            name: sub.plan.name,
            price: sub.plan.price,
            period: sub.plan.period,
            benefits: parseBenefits(sub.plan.benefits),
            isActive: sub.plan.isActive,
          },
          status: sub.status,
          startedAt: sub.startedAt.toISOString(),
          currentPeriodEnd: sub.currentPeriodEnd.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/subscription/my] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구독 현황을 불러오지 못했습니다." },
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
