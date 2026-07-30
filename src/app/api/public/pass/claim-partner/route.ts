// 공개(비인증) 파트너 제휴 알림패스 발급 API — Flutter PassRepository.claimPartner() 대응.
// 제휴 랜딩(linkUrl) 방문 완료 콜백 시 호출. claim-ad와 동일한 발급 로직이나
// passType="partner" 정책을 사용한다(문서3 정책표: 3시간, 1일 1회, 보너스 10P).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; policyId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);

  try {
    const policy = body.policyId
      ? await prisma.passPolicy.findFirst({
          where: {
            id: Number(body.policyId),
            passType: "partner",
            isActive: true,
            deletedAt: null,
          },
        })
      : await prisma.passPolicy.findFirst({
          where: { passType: "partner", isActive: true, deletedAt: null },
          orderBy: { id: "asc" },
        });

    if (!policy) {
      return NextResponse.json(
        { success: false, error: "활성화된 파트너 알림패스 정책이 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    if (policy.dailyLimit != null) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayCount = await prisma.userPass.count({
        where: { userId, policyId: policy.id, createdAt: { gte: todayStart } },
      });
      if (todayCount >= policy.dailyLimit) {
        return NextResponse.json(
          { success: false, error: "오늘의 파트너 알림패스 발급 한도를 초과했습니다." },
          { status: 429, headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const expiresAt = new Date(now.getTime() + policy.durationMin * 60 * 1000);

      const userPass = await tx.userPass.create({
        data: {
          userId,
          policyId: policy.id,
          activatedAt: now,
          expiresAt,
          sourceType: "partner",
        },
      });

      let balanceAfter: number | null = null;
      if (policy.bonusPoint > 0) {
        let wallet = await tx.wallet.findFirst({
          where: { userId, currencyType: "POINT", deletedAt: null },
        });
        if (!wallet) {
          wallet = await tx.wallet.create({ data: { userId, currencyType: "POINT", balance: 0 } });
        }
        balanceAfter = wallet.balance + policy.bonusPoint;
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: balanceAfter, balanceSyncedAt: now },
        });
        await tx.pointHistory.create({
          data: {
            walletId: wallet.id,
            userId,
            amount: policy.bonusPoint,
            type: "earn",
            sourceType: "pass_partner_bonus",
            sourceId: userPass.id,
            balanceAfter,
            memo: `파트너 알림패스 지급 보너스: ${policy.name}`,
          },
        });
      }

      await tx.operationLog.create({
        data: {
          actorType: "user",
          actorId: userId,
          action: "claim_partner_pass",
          targetType: "user_pass",
          targetId: userPass.id,
          before: null,
          after: JSON.stringify({ policyId: policy.id, expiresAt: expiresAt.toISOString() }),
        },
      });

      return { userPass, expiresAt, balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: result.userPass.id,
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: result.expiresAt.toISOString(),
          bonusPoint: policy.bonusPoint,
          balanceAfter: result.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/claim-partner] 실패:", e);
    return NextResponse.json(
      { success: false, error: "파트너 알림패스 발급 중 오류가 발생했습니다." },
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
