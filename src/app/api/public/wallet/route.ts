// 공개(비인증) 지갑(Wallet) 조회 API — Flutter 앱의 WalletRepository가 사용할 엔드포인트.
//
// [배경] 04A C-1 wallets / C-2 point_histories 테이블은 이미 존재하지만, 이를 앱에서
// 조회할 수 있는 공개 API가 없어 Flutter WalletRepository가 전부 로컬 Mock(고정값 12500P)으로
// 동작하고 있었다. 이 라우트를 신설하여 실제 DB 잔액/내역을 반환한다.
//
// [인증 임시 방편] 아직 회원 로그인 시스템이 없으므로, userId를 쿼리 파라미터로 받는다
// (기본값 1 = 시딩된 테스트 유저 "별빛나그네"). 향후 실제 로그인 붙으면 세션에서 userId를
// 추출하도록 교체하되, 이 API의 응답 스키마는 유지한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "Access-Control-Allow-Origin": "*",
};

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let wallet = await prisma.wallet.findFirst({
    where: { userId, currencyType: "POINT", deletedAt: null },
  });

  // 지갑이 아직 없는 유저(예: 신규 시딩 유저)는 0P로 즉석 생성한다.
  if (!wallet) {
    wallet = await prisma.wallet.create({
      data: { userId, currencyType: "POINT", balance: 0, balanceSyncedAt: new Date() },
    });
  }

  const histories = await prisma.pointHistory.findMany({
    where: { walletId: wallet.id },
    orderBy: { createdAt: "desc" },
    take: 50,
  });

  return NextResponse.json(
    {
      success: true,
      data: {
        balance: wallet.balance,
        history: histories.map((h) => ({
          id: h.id,
          type: h.type, // earn/spend
          amount: h.amount,
          reason: h.memo ?? h.sourceType,
          createdAt: h.createdAt.toISOString(),
        })),
      },
    },
    { headers: CORS_HEADERS }
  );
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
