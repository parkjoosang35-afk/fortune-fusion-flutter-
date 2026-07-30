// 공개(비인증) 소원성(Wish Castle) "복주머니 보내기" API — 신규.
//
// [설계 원칙] 기존 /wishes/[id]/support(단순 응원 on/off, 포인트 이동 없음)와는
// 완전히 별개의 신규 엔드포인트다. "복주머니"는 기존 LuckyBag(가챠, 포인트 소모)나
// "복 나누기"(WalletRepository.sendBok, 실제 포인트 이동)와도 다른 개념으로,
// 소원성 안에서만 통용되는 상징적 응원 단위이며 실제 포인트/지갑 이동이 전혀 없다.
// 누적치(wishes.bokju_count)가 wish_config의 레벨 임계값을 넘으면 촛불 레벨이
// 오르고, 최종 레벨(4) 최초 도달 시 achievedAt을 기록한다(특별연출 1회 트리거용).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { computeCandleLevel, getCandleLevelThresholds, WISH_MAX_LEVEL } from "@/lib/wish-castle";

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

      return { updated, leveledUp, previousLevel: wish.candleLevel };
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
