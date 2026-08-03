// 공개(비인증) 소원성(Wish Castle) "복주머니 보내기" API.
//
// [재화 구조 정리 - 재연결] 기존에는 "실제 재화 이동이 없는 상징적 응원"으로
// 설계되었으나, 최종 2-자산 구조(프리패스+복주머니) 확정에 따라 "복주머니 사용
// 구간표(응원)" 항목과 재연결한다. 사용자가 보내기로 선택한 개수(amount)만큼
// 실제 지갑(Wallet)에서 차감한 뒤, 소원의 누적치(wishes.bokju_count)를 올린다.
// 잔액이 부족하면 차감 자체를 막고 409로 응답한다(부분 실패 없는 원자적 트랜잭션).
// 누적치가 wish_config의 레벨 임계값을 넘으면 촛불 레벨이 오르고, 최종 레벨(4)
// 최초 도달 시 achievedAt을 기록한다(특별연출 1회 트리거용).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { computeCandleLevel, getCandleLevelThresholds, WISH_MAX_LEVEL } from "@/lib/wish-castle";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const ALLOWED_AMOUNTS = [1, 5, 10, 50, 100];

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

  let body: { userId?: number; amount?: number };
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
  if (!ALLOWED_AMOUNTS.includes(amount)) {
    return NextResponse.json(
      { success: false, error: "보낼 수 있는 복주머니 개수가 아닙니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const wish = await tx.wish.findUnique({ where: { id: wishId } });
      if (!wish) throw new Error("WISH_NOT_FOUND");

      // [재화 구조 정리] 복주머니 사용 구간표(응원) - 실제 지갑에서 amount만큼 차감.
      // 잔액 부족 시 소원 상태를 건드리지 않고 트랜잭션 전체를 되돌린다.
      const spendResult = await spendLuckPouch(tx, {
        userId,
        amount,
        sourceType: "wish_bokju_send",
        sourceId: wishId,
        memo: "소원 응원(복주머니 보내기)",
      });
      if (!spendResult.ok) {
        throw new Error(`INSUFFICIENT_BALANCE:${spendResult.balanceAfter ?? 0}`);
      }

      await tx.wishBokju.create({
        data: { wishId, userId, amount, source: "manual" },
      });

      const newBokjuCount = wish.bokjuCount + amount;
      const thresholds = await getCandleLevelThresholds();
      const newLevel = computeCandleLevel(newBokjuCount, thresholds);
      const leveledUp = newLevel > wish.candleLevel;
      const reachedMax = newLevel >= WISH_MAX_LEVEL && wish.candleLevel < WISH_MAX_LEVEL;

      const updated = await tx.wish.update({
        where: { id: wishId },
        data: {
          bokjuCount: newBokjuCount,
          candleLevel: newLevel,
          achievedAt: reachedMax ? new Date() : wish.achievedAt,
        },
      });

      return {
        updated,
        leveledUp,
        previousLevel: wish.candleLevel,
        balanceAfter: spendResult.balanceAfter,
      };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `wp_${result.updated.id}`,
          bokjuCount: result.updated.bokjuCount,
          candleLevel: result.updated.candleLevel,
          previousLevel: result.previousLevel,
          leveledUp: result.leveledUp,
          achievedAt: result.updated.achievedAt?.toISOString() ?? null,
          isMilestoneShown: result.updated.isMilestoneShown,
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
    if (message.startsWith("INSUFFICIENT_BALANCE:")) {
      const balance = Number(message.split(":")[1] ?? 0);
      return NextResponse.json(
        {
          success: false,
          error: "복주머니가 부족합니다.",
          data: { balance },
        },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/wishes/[id]/bokju] 실패:", e);
    return NextResponse.json(
      { success: false, error: "복주머니 보내기에 실패했습니다." },
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
