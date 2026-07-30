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

      // [Fortune Fusion 3축 정책] 구독 = "알림패스 자동/추가 지급 + 복주머니 정기 지급"
      // 구독 성공 시 passType="subscription" 정책을 조회해 UserPass를 즉시 발급하고,
      // bonusPoint가 있으면 복주머니(포인트)도 함께 지급한다(claim-ad/route.ts와 동일한
      // 트랜잭션 패턴 재사용). 정책이 비활성/미시딩 상태면 조용히 건너뛴다(구독 자체는 유효).
      let issuedPass: { userPassId: number; policyId: number; policyName: string; expiresAt: Date; bonusPoint: number } | null = null;
      const passPolicy = await tx.passPolicy.findFirst({
        where: { passType: "subscription", isActive: true, deletedAt: null },
        orderBy: { id: "asc" },
      });
      if (passPolicy) {
        const passExpiresAt = new Date(now.getTime() + passPolicy.durationMin * 60 * 1000);
        const userPass = await tx.userPass.create({
          data: {
            userId,
            policyId: passPolicy.id,
            activatedAt: now,
            expiresAt: passExpiresAt,
            sourceType: "subscription",
          },
        });

        let wallet = await tx.wallet.findFirst({
          where: { userId, currencyType: "POINT", deletedAt: null },
        });
        if (!wallet) {
          wallet = await tx.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
        }
        if (passPolicy.bonusPoint > 0) {
          const balanceAfter = wallet.balance + passPolicy.bonusPoint;
          await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance: balanceAfter, balanceSyncedAt: now },
          });
          await tx.pointHistory.create({
            data: {
              walletId: wallet.id,
              userId,
              amount: passPolicy.bonusPoint,
              type: "earn",
              sourceType: "pass_subscription_bonus",
              sourceId: userPass.id,
              balanceAfter,
              memo: `구독 알림패스 지급 보너스: ${passPolicy.name}`,
            },
          });
        }

        await tx.operationLog.create({
          data: {
            actorType: "user",
            actorId: userId,
            action: "claim_subscription_pass",
            targetType: "user_pass",
            targetId: userPass.id,
            before: null,
            after: JSON.stringify({
              policyId: passPolicy.id,
              subscriptionId: subscription.id,
              expiresAt: passExpiresAt.toISOString(),
            }),
          },
        });

        issuedPass = {
          userPassId: userPass.id,
          policyId: passPolicy.id,
          policyName: passPolicy.name,
          expiresAt: passExpiresAt,
          bonusPoint: passPolicy.bonusPoint,
        };
      }

      return { subscription, issuedPass };
    });

    const { subscription, issuedPass } = result;
    return NextResponse.json(
      {
        success: true,
        data: {
          id: `sub_${subscription.id}`,
          plan: {
            id: `plan_${subscription.plan.id}`,
            name: subscription.plan.name,
            price: subscription.plan.price,
            period: subscription.plan.period,
            benefits: parseBenefits(subscription.plan.benefits),
            isActive: subscription.plan.isActive,
          },
          status: subscription.status,
          startedAt: subscription.startedAt.toISOString(),
          currentPeriodEnd: subscription.currentPeriodEnd.toISOString(),
          // [Fortune Fusion 3축 정책] 구독 성공 시 함께 발급된 알림패스 정보.
          // passPolicy가 시딩되어 있지 않으면 null(구독 자체는 정상 처리됨).
          issuedPass: issuedPass
            ? {
                userPassId: issuedPass.userPassId,
                policyId: issuedPass.policyId,
                policyName: issuedPass.policyName,
                expiresAt: issuedPass.expiresAt.toISOString(),
                bonusPoint: issuedPass.bonusPoint,
              }
            : null,
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
