// 공개(비인증) 구독 시작(결제 시뮬레이션 포함) API — SubscriptionRepository.subscribe() 대응.
//
// [2026-11-11 신통방통 관리자 2.0 전면 재설계 - 구독 "정책준비중" 전환]
// 과거 더미 플랜 4개 + 더미 구독 10건 + 더미 결제 6건이 전부 앱 미출시 상태의
// 테스트 시드 데이터로 확인되어 완전삭제했다(사용자 확정: "앱 출시도 안했는데
// 무슨 구독자냐"). 구독 기능 자체는 "정책 준비중" 상태로 코드 뼈대만 유지하고,
// subscription_plans 테이블이 비어있는 한 이 엔드포인트는 항상 안내 메시지만
// 반환한다(플랜이 추가되는 순간 기존 로직이 자동으로 재가동되는 구조는 유지).
import { NextRequest, NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/db";
import { countPassGrantFields, OpenPassServiceError } from "@/lib/open-pass-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

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

  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  const planId = body.planId ? parsePlanId(body.planId) : null;
  if (planId === null) {
    return NextResponse.json(
      { success: false, error: "존재하지 않는 플랜입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  // [정책준비중] subscription_plans가 비어있으면(현재 정상 상태) 명확한 안내로
  // 즉시 응답한다 — 아래 트랜잭션은 plan이 생기면 그대로 재사용된다.
  const activePlanCount = await prisma.subscriptionPlan.count({
    where: { isActive: true, deletedAt: null },
  });
  if (activePlanCount === 0) {
    return NextResponse.json(
      { success: false, error: "구독 서비스는 현재 준비 중입니다." },
      { status: 503, headers: CORS_HEADERS }
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
        const grantFields = countPassGrantFields(passPolicy, now);
        const passExpiresAt = grantFields.expiresAt;
        const userPass = await tx.userPass.create({
          data: {
            userId,
            policyId: passPolicy.id,
            activatedAt: now,
            ...grantFields,
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
          // [경제 감사 2026-10-12 M-2] 구독→해지→재구독 루프로 보너스 포인트를
          // 무한 파밍하던 구멍을 막는다 — 동일 유저에게 pass_subscription_bonus
          // 원장이 하나라도 있으면 재지급하지 않는다(평생 1회). 구독 자체와
          // 알림패스 발급은 정상 계속된다.
          const priorBonus = await tx.pointHistory.findFirst({
            where: { userId, sourceType: "pass_subscription_bonus" },
            select: { id: true },
          });
          if (priorBonus) {
            // 이미 수령한 이력이 있으면 포인트 지급만 생략한다.
          } else {
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
    if (e instanceof OpenPassServiceError) {
      return NextResponse.json({ success: false, error: e.message, code: e.code }, { status: 409, headers: CORS_HEADERS });
    }
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
