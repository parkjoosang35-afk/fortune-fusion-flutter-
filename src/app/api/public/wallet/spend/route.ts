// 공개(비인증) 지갑 차감(spend) API — WalletRepository.spend() 대응.
// 잔액이 부족하면 트랜잭션 내에서 즉시 실패(success:false) 반환하고 아무 것도 반영하지 않는다.
//
// [2026-11-11 신통방통 관리자 2.0 전면 재설계 - 복주머니 경제구조 정상화]
// 과거 "소모 시 즉시 50% 환급"(이른바 "증식") 로직이 있었으나, 사용자 확정
// 결정에 따라 완전 삭제한다. 복주머니는 "쓰면 줄어드는" 정상적인 재화 구조로
// 되돌린다(economy_config.refund_rate 설정값/관리자 폼도 함께 제거).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; amount?: number; reason?: string; sourceType?: string };
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
  const amount = Number(body.amount);
  const reason = body.reason ?? "차감";
  const sourceType = body.sourceType ?? "purchase";

  if (!Number.isInteger(amount) || amount <= 0) {
    return NextResponse.json(
      { success: false, error: "amount는 1 이상의 정수여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) {
        throw new Error("WALLET_NOT_FOUND");
      }
      if (wallet.balance < amount) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      const balance = wallet.balance - amount;

      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance, balanceSyncedAt: new Date() },
      });

      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: -amount,
          type: "spend",
          sourceType,
          balanceAfter: balance,
          memo: reason,
        },
      });

      return { balance };
    });

    return NextResponse.json(
      {
        success: true,
        data: { balance: result.balance, refundAmount: 0 },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json(
        { success: false, error: "포인트가 부족합니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    if (message === "WALLET_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "지갑을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wallet/spend] 실패:", e);
    return NextResponse.json(
      { success: false, error: "차감 처리 중 오류가 발생했습니다." },
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
