// 공개(비인증) 구독 시작(결제 시뮬레이션 포함) API — SubscriptionRepository.subscribe() 대응.
//
// [범위] 실제 PG 연동은 범위 밖(Mock 시뮬레이션 유지, 기존 Mock Repository와 동일 원칙).
// 서버는 결제레코드(payments) + 구독레코드(user_subscriptions) 생성만 담당한다.
// 기존 활성 구독이 있으면 cancelled로 전환 후 새 구독을 생성한다(플랜 변경 지원).
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePlanId(idParam: string): number | null {
  const match = /^plan_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

function parseBenefits(raw: string): string[] {
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((x) => typeof x === "string") : [];
  } catch {
    return [];
  }
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; planId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const planId = body.planId ? parsePlanId(body.planId) : null;
  if (planId === null) {
    return NextResponse.json(
      { success: false, error: "존재하지 않는 플랜입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const plan = await tx.subscriptionPlan.findFirst({
        where: { id: planId, isActive: true, deletedAt: null },
      });
      if (!plan) throw new Error("PLAN_NOT_FOUND");
      if (plan.price <= 0) throw new Error("FREE_PLAN");

      await tx.payment.create({
        data: {
          userId,
          orderType: "subscription",
          amount: plan.price,
          pgProvider: "toss",
          pgTxId: `TOSS-TX-${randomUUID().slice(0, 12)}`,
          status: "paid",
        },
      });

      // 기존 활성 구독은 취소 처리(플랜 변경 시나리오)
      await tx.userSubscription.updateMany({
        where: { userId, status: "active", deletedAt: null },
        data: { status: "cancelled" },
      });

      const now = new Date();
      const periodEnd =
        plan.period === "yearly"
          ? new Date(now.getFullYear() + 1, now.getMonth(), now.getDate())
          : new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

      const subscription = await tx.userSubscription.create({
        data: {
          userId,
          planId: plan.id,
          status: "active",
          startedAt: now,
          currentPeriodEnd: periodEnd,
          pgSubscriptionId: `sub_toss_${randomUUID().slice(0, 8)}`,
        },
        include: { plan: true },
      });
      return subscription;
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `sub_${result.id}`,
          plan: {
            id: `plan_${result.plan.id}`,
            name: result.plan.name,
            price: result.plan.price,
            period: result.plan.period,
            benefits: parseBenefits(result.plan.benefits),
            isActive: result.plan.isActive,
          },
          status: result.status,
          startedAt: result.startedAt.toISOString(),
          currentPeriodEnd: result.currentPeriodEnd.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "PLAN_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 플랜입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "FREE_PLAN") {
      return NextResponse.json(
        { success: false, error: "무료 플랜은 별도 결제가 필요하지 않습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/subscription/subscribe] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구독 처리 중 오류가 발생했습니다." },
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
