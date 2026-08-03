// 공개(비인증) "복주머니로 프리패스 구매" 실행 API — Flutter
// PassRepository.purchaseWithLuckPouch() 대응.
// [재화 구조 정리] 복주머니 사용 구간표: 프리패스30분-30, 1시간-50, 24시간-150.
// PassPolicy.happyMoneyPrice가 설정된 정책만 구매 가능하며, 지갑(Wallet/POINT)에서
// 해당 금액을 차감(spendLuckPouch)한 뒤 UserPass를 발급한다. 프리패스는 순수
// 시간제 이용권이므로 구매 시 별도의 상시 적립/보너스를 붙이지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";

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
  const policyId = Number(body.policyId ?? 0);

  if (!policyId) {
    return NextResponse.json(
      { success: false, error: "policyId가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const policy = await prisma.passPolicy.findFirst({
      where: { id: policyId, isActive: true, deletedAt: null },
    });

    if (!policy) {
      return NextResponse.json(
        { success: false, error: "존재하지 않거나 비활성화된 프리패스 정책입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    if (policy.happyMoneyPrice == null) {
      return NextResponse.json(
        { success: false, error: "이 프리패스는 복주머니 구매가 불가능합니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }

    const price = policy.happyMoneyPrice;

    const result = await prisma.$transaction(async (tx) => {
      const spendResult = await spendLuckPouch(tx, {
        userId,
        amount: price,
        sourceType: "pass_purchase",
        sourceId: policy.id,
        memo: `프리패스 구매: ${policy.name}`,
      });

      if (!spendResult.ok) {
        return { spendResult, userPass: null, expiresAt: null as Date | null };
      }

      const now = new Date();
      const expiresAt = new Date(now.getTime() + policy.durationMin * 60 * 1000);

      const userPass = await tx.userPass.create({
        data: {
          userId,
          policyId: policy.id,
          activatedAt: now,
          expiresAt,
          sourceType: "luck_pouch_purchase",
        },
      });

      await tx.operationLog.create({
        data: {
          actorType: "user",
          actorId: userId,
          action: "purchase_pass_with_luck_pouch",
          targetType: "user_pass",
          targetId: userPass.id,
          before: null,
          after: JSON.stringify({
            policyId: policy.id,
            price,
            balanceAfter: spendResult.balanceAfter,
            expiresAt: expiresAt.toISOString(),
          }),
        },
      });

      return { spendResult, userPass, expiresAt };
    });

    if (!result.spendResult.ok) {
      return NextResponse.json(
        {
          success: false,
          error: "보유한 복주머니가 부족합니다.",
          data: { balance: result.spendResult.balanceAfter },
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: result.userPass!.id,
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: result.expiresAt!.toISOString(),
          balanceAfter: result.spendResult.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/purchase-with-luck-pouch] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프리패스 구매 중 오류가 발생했습니다." },
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
