// 공개(비인증) 지갑 차감(spend) API — WalletRepository.spend() 대응.
// 잔액이 부족하면 트랜잭션 내에서 즉시 실패(success:false) 반환하고 아무 것도 반영하지 않는다.
//
// [Phase22 - 복주머니 경제철학 이식] "소모 시 즉시 50% 환급" 로직 추가.
// 새 마스터 프롬프트(2부 복주머니 경제엔진)의 핵심 철학을 옵션B(기존 스택 유지)로 이식한다.
// 적용범위(사용자 승인 결정②): "운세/AI서비스 소모"에만 환급 적용, luckybag(뽑기 구매) 등에는 미적용
// (뽑기는 이미 확률형 보상을 받는 구조라 이중혜택 방지).
// 환급률은 economy_config.refund_rate 값을 사용하며, 관리자가 대시보드에서 즉시 조정 가능.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// 환급 대상 sourceType 판별 — "운세/AI서비스" 계열만 대상으로 한다.
// 기존 카탈로그 기준: ai_consultation_message, ai_daily_request, ai_face_request,
// ai_palm_request, ai_saju_request, ai_tarot_request 등은 모두 "ai_" 접두사를 사용 중.
// 향후 추가될 "오늘의 운세" 등 비-AI 운세 서비스는 "fortune_" 접두사로 통일해 자동 대상 포함.
// luckybag, admin_adjust, attendance, community, event, mission, refund, test 등은 제외.
function isRefundEligibleSourceType(sourceType: string): boolean {
  return sourceType.startsWith("ai_") || sourceType.startsWith("fortune_");
}

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

  const userId = Number(body.userId ?? 1);
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

      // 1) 차감 먼저 반영
      let balance = wallet.balance - amount;

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

      // 2) 환급 대상(운세/AI서비스)이면 economy_config.refund_rate만큼 즉시 환급
      let refundAmount = 0;
      if (isRefundEligibleSourceType(sourceType)) {
        const config = await tx.economyConfig.findUnique({
          where: { key: "refund_rate" },
        });
        const refundRate = config?.value ?? 0.5;
        refundAmount = Math.floor(amount * refundRate);

        if (refundAmount > 0) {
          balance += refundAmount;

          await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance, balanceSyncedAt: new Date() },
          });

          await tx.pointHistory.create({
            data: {
              walletId: wallet.id,
              userId,
              amount: refundAmount,
              type: "earn",
              sourceType: "refund",
              sourceId: null,
              balanceAfter: balance,
              memo: `${reason} 이용 환급 (${Math.round(refundRate * 100)}%)`,
            },
          });
        }
      }

      return { balance, refundAmount };
    });

    return NextResponse.json(
      {
        success: true,
        data: { balance: result.balance, refundAmount: result.refundAmount },
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
