// 소원함 개봉(Box Opening) 완료 기록 API — bokjumeoni-plan §03 SERVER API
// `PATCH /wishes/:id/opened` 대응.
//
// [역할] 07 Box Opening 화면을 실제로 다 봤을 때 서버 openedBoxAt을
// 기록한다. 이렇게 해야 GET /wishes/pending-openings가 다시는 같은 소원을
// 후보로 돌려주지 않는다(Phase01의 SharedPreferences 로컬 기록을 서버
// 원장으로 승격 — 기기를 바꿔도 유지되고, 관리자가 원장을 확인할 수 있음).
//
// [주의] "주간 소원함 개봉" 보너스(weekly_box_opening)는 이 API가 아니라
// 여전히 Flutter가 BlessingBagPolicyAdapter.earnWeeklyBoxOpeningBonus()를
// 통해 /wallet/earn 경유로 별도 처리한다(이 API와 무관 — 혼동 주의).
//
// [소원방 마무리 - Phase B] wish_100days(+30, 소원당 1회, "자동 배치")는
// 이 API에서 지급한다. "100일 지킴"이 확정되는 시점은 곧 unlockAt이 지나
// pending-openings 후보가 되어 07 화면이 실제로 열리는(=openedBoxAt을
// 최초로 기록하는) 이 순간이므로, fulfilled/route.ts와 동일한 패턴
// ($transaction + checkPolicyEligibility(sourceId=wishId) + earnLuckPouch)
// 으로 상태 갱신과 지급을 하나의 트랜잭션에 묶는다. "자동 배치"(사용자가
// 버튼을 누르는 게 아니라 100일이 지나면 서버 상태가 자동으로 그렇게 됨)
// 의미를 그대로 반영 — 별도의 cron/배치 잡 없이 이 idempotent PATCH가
// 최초 호출되는 순간을 "100일 도달 확정 시점"으로 삼는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { checkPolicyEligibility, earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  parseWishDbId,
  requireUser,
  toWishDto,
  unauthorizedResponse,
  type WishRow,
} from "../../_shared";

export const dynamic = "force-dynamic";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  const { id } = await params;
  const dbId = parseWishDbId(id);
  if (dbId === null) {
    return NextResponse.json(
      { success: false, error: "wishId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const existing = await tx.wish.findUnique({ where: { id: dbId } });
      if (!existing || existing.deletedAt != null) {
        throw new Error("WISH_NOT_FOUND");
      }
      // 본인 소원만 "개봉 완료" 처리를 할 수 있다(타인의 pending-openings에
      // 영향을 줄 수 없어야 함).
      if (existing.userId !== auth.userId) {
        throw new Error("NOT_OWNER");
      }

      // 이미 openedBoxAt이 있으면 값을 덮어쓰지 않고 그대로 반환한다
      // (idempotent — 같은 소원에 대해 여러 번 호출돼도 최초 시각을 유지).
      // wish_100days 지급도 "최초 개봉" 시점 1회만 시도한다(이미 개봉된
      // 소원을 다시 호출해도 재지급되지 않도록).
      if (existing.openedBoxAt) {
        return { wish: existing, grantedAmount: 0 };
      }

      const updated = await tx.wish.update({
        where: { id: dbId },
        data: { openedBoxAt: new Date() },
      });

      // [Phase B] sourceId=wishId 기반 "소원당 1회" 판정(dailyLimit 무관,
      // fulfilled/route.ts와 동일 패턴).
      const eligibility = await checkPolicyEligibility(tx, auth.userId, "wish_100days", {
        scope: "daily",
        sourceId: updated.id,
      });

      let grantedAmount = 0;
      if (eligibility.eligible) {
        const policy = await tx.pointPolicy.findUnique({
          where: { sourceType: "wish_100days" },
        });
        const amount = policy?.amount ?? 0;
        if (amount > 0) {
          const outcome = await earnLuckPouch(tx, {
            userId: auth.userId,
            amount,
            sourceType: "wish_100days",
            sourceId: updated.id,
            memo: "100일 지킴 축하",
          });
          grantedAmount = outcome.grantedAmount;
        }
      }

      return { wish: updated, grantedAmount };
    });

    const withUser = await prisma.wish.findUnique({
      where: { id: result.wish.id },
      include: { user: { select: { nickname: true } } },
    });

    const dto = toWishDto(withUser as unknown as WishRow, auth.userId);
    return NextResponse.json(
      { success: true, data: { ...dto, grantedAmount: result.grantedAmount } },
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
    if (message === "NOT_OWNER") {
      return NextResponse.json(
        { success: false, error: "본인의 소원만 개봉 처리할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    console.error("[PATCH /api/public/wishes/:id/opened] 실패:", e);
    return NextResponse.json(
      { success: false, error: "개봉 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "PATCH, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
