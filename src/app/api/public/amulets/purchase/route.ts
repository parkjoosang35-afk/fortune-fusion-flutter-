// 공개(비인증) 부적 구매 API — Flutter AmuletRepository.purchase() 대응.
// 지갑(POINT) 차감 + user_amulets 발급을 하나의 트랜잭션으로 처리한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseItemId(raw: unknown): number | null {
  const s = String(raw ?? "");
  const m = s.match(/^am_(\d+)$/) ?? s.match(/^(\d+)$/);
  if (!m) return null;
  return Number(m[1]);
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; itemId?: string | number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const itemId = parseItemId(body.itemId);
  if (itemId == null) {
    return NextResponse.json(
      { success: false, error: "itemId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const item = await tx.amuletItem.findFirst({
        where: { id: itemId, status: "active", deletedAt: null },
        include: { grade: true },
      });
      if (!item) {
        throw new Error("NOT_FOUND");
      }

      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      const balance = wallet?.balance ?? 0;
      if (balance < item.pricePoint) {
        throw new Error("INSUFFICIENT_BALANCE");
      }

      const newBalance = balance - item.pricePoint;
      const walletRow = wallet
        ? await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance: newBalance, balanceSyncedAt: new Date() },
          })
        : await tx.wallet.create({
            data: { userId, currencyType: "POINT", balance: newBalance },
          });

      await tx.pointHistory.create({
        data: {
          walletId: walletRow.id,
          userId,
          amount: -item.pricePoint,
          type: "spend",
          sourceType: "amulet_purchase",
          sourceId: item.id,
          balanceAfter: newBalance,
          memo: `부적 구매: ${item.name}`,
        },
      });

      const userAmulet = await tx.userAmulet.create({
        data: {
          userId,
          amuletItemId: item.id,
          sourceType: "purchase",
          status: "held",
        },
      });

      return { userAmulet, item, newBalance };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `ua_${outcome.userAmulet.id}`,
          itemId: `am_${outcome.item.id}`,
          itemName: outcome.item.name,
          status: outcome.userAmulet.status,
          acquiredAt: outcome.userAmulet.acquiredAt.toISOString(),
          balanceAfter: outcome.newBalance,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 상품입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "INSUFFICIENT_BALANCE") {
      return NextResponse.json(
        { success: false, error: "복주머니 잔액이 부족합니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/amulets/purchase] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 구매 처리 중 오류가 발생했습니다." },
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
