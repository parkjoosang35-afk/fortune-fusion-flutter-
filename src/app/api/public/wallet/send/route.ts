// 공개(비인증) 지갑 "복 보내기(송금)" API — WalletRepository.sendBok() 대응.
//
// [Phase22 - 복주머니 경제철학 이식] 새 마스터 프롬프트(2부 복주머니 경제엔진)의
// "송금 시 양쪽 증식" 철학을 옵션B(기존 스택 유지)로 이식한다.
//   - 보낸 사람: amount만큼 차감되지만, economy_config.send_refund_rate만큼 즉시 환급받아
//     실질적으로는 amount * (1 - send_refund_rate)만 순수 소모한다.
//   - 받은 사람: amount 전액을 그대로 적립받는다.
//   - 즉 "보내는 행위" 자체가 양쪽 모두에게 포인트를 늘려주는 구조(디플레이션 방지 + 나눔 유도).
//
// 일일 한도(economy_config.daily_send_limit)를 적용해 인플레이션(과도한 셀프 송금 등)을 방어한다.
// [인증 임시 방편] 아직 로그인 시스템이 없으므로 fromUserId/toUserId를 바디로 직접 받는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: {
    fromUserId?: number;
    toUserId?: number;
    amount?: number;
    memo?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const fromUserId = Number(body.fromUserId);
  const toUserId = Number(body.toUserId);
  const amount = Number(body.amount);
  const memo = body.memo ?? "복 나누기";

  if (!Number.isInteger(fromUserId) || fromUserId <= 0) {
    return NextResponse.json(
      { success: false, error: "fromUserId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!Number.isInteger(toUserId) || toUserId <= 0) {
    return NextResponse.json(
      { success: false, error: "toUserId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (fromUserId === toUserId) {
    return NextResponse.json(
      { success: false, error: "자기 자신에게는 보낼 수 없습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!Number.isInteger(amount) || amount <= 0) {
    return NextResponse.json(
      { success: false, error: "amount는 1 이상의 정수여야 합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 0) economy_config 로드 (없으면 기본값 fallback)
      const [sendRefundConfig, dailyLimitConfig] = await Promise.all([
        tx.economyConfig.findUnique({ where: { key: "send_refund_rate" } }),
        tx.economyConfig.findUnique({ where: { key: "daily_send_limit" } }),
      ]);
      const sendRefundRate = sendRefundConfig?.value ?? 0.5;
      const dailySendLimit = dailyLimitConfig?.value ?? 200;

      // 1) 일일 한도 체크 — 오늘(자정 이후) 이미 보낸 총액 + 이번 요청 amount
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      const sentToday = await tx.pointHistory.aggregate({
        where: {
          userId: fromUserId,
          sourceType: "send_bok",
          type: "spend",
          createdAt: { gte: todayStart },
        },
        _sum: { amount: true },
      });
      // amount는 spend라 음수로 저장되어 있으므로 절댓값으로 환산
      const alreadySentToday = Math.abs(sentToday._sum.amount ?? 0);

      if (alreadySentToday + amount > dailySendLimit) {
        throw new Error("DAILY_LIMIT_EXCEEDED");
      }

      // 2) 보낸 사람 지갑 조회 및 잔액 체크
      const fromWallet = await tx.wallet.findFirst({
        where: { userId: fromUserId, currencyType: "POINT", deletedAt: null },
      });
      if (!fromWallet) {
        throw new Error("WALLET_NOT_FOUND");
      }
      if (fromWallet.balance < amount) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      // 3) 보낸 사람: 차감
      let fromBalance = fromWallet.balance - amount;
      await tx.wallet.update({
        where: { id: fromWallet.id },
        data: { balance: fromBalance, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: fromWallet.id,
          userId: fromUserId,
          amount: -amount,
          type: "spend",
          sourceType: "send_bok",
          sourceId: toUserId,
          balanceAfter: fromBalance,
          memo: `${memo} (받는사람 #${toUserId})`,
        },
      });

      // 4) 보낸 사람: 즉시 환급(send_refund_rate) — "양쪽 증식"의 절반
      const refundAmount = Math.floor(amount * sendRefundRate);
      if (refundAmount > 0) {
        fromBalance += refundAmount;
        await tx.wallet.update({
          where: { id: fromWallet.id },
          data: { balance: fromBalance, balanceSyncedAt: new Date() },
        });
        await tx.pointHistory.create({
          data: {
            walletId: fromWallet.id,
            userId: fromUserId,
            amount: refundAmount,
            type: "earn",
            sourceType: "refund",
            sourceId: toUserId,
            balanceAfter: fromBalance,
            memo: `복 나누기 환급 (${Math.round(sendRefundRate * 100)}%)`,
          },
        });
      }

      // 5) 받는 사람: 지갑 없으면 즉석 생성 후 전액 적립
      let toWallet = await tx.wallet.findFirst({
        where: { userId: toUserId, currencyType: "POINT", deletedAt: null },
      });
      if (!toWallet) {
        toWallet = await tx.wallet.create({
          data: { userId: toUserId, currencyType: "POINT", balance: 0 },
        });
      }
      const toBalance = toWallet.balance + amount;
      await tx.wallet.update({
        where: { id: toWallet.id },
        data: { balance: toBalance, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: toWallet.id,
          userId: toUserId,
          amount,
          type: "earn",
          sourceType: "receive_bok",
          sourceId: fromUserId,
          balanceAfter: toBalance,
          memo: `${memo} (보낸사람 #${fromUserId})`,
        },
      });

      return {
        fromBalance,
        refundAmount,
        dailySendRemaining: dailySendLimit - (alreadySentToday + amount),
      };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          balance: result.fromBalance,
          refundAmount: result.refundAmount,
          dailySendRemaining: result.dailySendRemaining,
        },
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
    if (message === "DAILY_LIMIT_EXCEEDED") {
      return NextResponse.json(
        { success: false, error: "오늘의 복 나누기 한도를 초과했습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wallet/send] 실패:", e);
    return NextResponse.json(
      { success: false, error: "송금 처리 중 오류가 발생했습니다." },
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
