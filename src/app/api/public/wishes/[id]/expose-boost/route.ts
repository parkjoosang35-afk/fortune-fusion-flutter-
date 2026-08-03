// 공개(비인증) 소원 "노출 강화(expose_boost)" API — 본인 소원에만 적용 가능.
//
// [재화 구조 정리 - 재연결] LuckPouchRule(spend/expose_boost, targetScope=wish_board)를
// 실제 기능과 연결한다. 복주머니를 소비해 자신의 소원 글을 일정 시간(24시간) 동안
// 피드 상단에 재노출한다 — GET /api/public/wishes(tab=all/mine)에서 boostedAt이
// 유효(24시간 이내)한 글을 화면 상단으로 재배치하는 방식으로 실제 효과를 낸다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { spendLuckPouch, getSpendRuleAmount } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const FALLBACK_AMOUNT = 15; // luck_pouch_rules(expose_boost) 시드 기본값과 동일

function parseWishDbId(idParam: string): number | null {
  const match = /^wp_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const wishId = parseWishDbId(id);
  if (wishId === null) {
    return NextResponse.json(
      { success: false, error: "소원 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wish.findUnique({ where: { id: wishId } });
      if (!wish) throw new Error("WISH_NOT_FOUND");
      if (wish.userId !== userId) throw new Error("FORBIDDEN");

      const amount = await getSpendRuleAmount(tx, "expose_boost", FALLBACK_AMOUNT);
      const spendResult = await spendLuckPouch(tx, {
        userId,
        amount,
        sourceType: "wish_expose_boost",
        sourceId: wishId,
        memo: "소원 노출 강화(expose_boost)",
      });
      if (!spendResult.ok) {
        throw new Error(`INSUFFICIENT_BALANCE:${spendResult.balanceAfter ?? 0}`);
      }

      const boostedAt = new Date();
      const updated = await tx.wish.update({
        where: { id: wishId },
        data: { boostedAt },
      });

      return { updated, amount, balanceAfter: spendResult.balanceAfter };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wp_${result.updated.id}`,
          boostedAt: result.updated.boostedAt?.toISOString() ?? null,
          amountSpent: result.amount,
          balanceAfter: result.balanceAfter,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WISH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "FORBIDDEN") {
      return NextResponse.json(
        { success: false, error: "본인 소원에만 노출 강화를 적용할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message.startsWith("INSUFFICIENT_BALANCE:")) {
      const balance = Number(message.split(":")[1] ?? 0);
      return NextResponse.json(
        { success: false, error: "복주머니가 부족합니다.", data: { balance } },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/[id]/expose-boost] 실패:", e);
    return NextResponse.json(
      { success: false, error: "노출 강화 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}
