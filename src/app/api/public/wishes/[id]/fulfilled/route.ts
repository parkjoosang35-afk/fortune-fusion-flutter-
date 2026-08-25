// 소원 성취(이루어짐) 기록 API — bokjumeoni-plan §03 SERVER API
// `PATCH /wishes/:id/fulfilled` 대응.
//
// [배경] 지금까지는 05 Detail 화면의 "✿ 이뤄졌어요"가 로컬 연출(08
// Celebration push)만 하고 서버에는 아무 것도 기록하지 않았다(주석:
// "서버에 실제 fulfilled 상태 필드가 아직 없으므로" — Phase02-A에서
// wishState/fulfilledAt 필드가 생겼으므로 이제 실제로 기록한다).
//
// [지급 정책] point_policies.wish_fulfilled(amount=3, dailyLimit=null)를
// 그대로 사용하되, "건당 1회"는 sourceId=wishId 기반 checkPolicyEligibility
// 중복 판정으로 강제한다(dailyLimit이 아니라 sourceId 중복 검사가 실제
// 방어선 — 이미 BlessingBagPolicyAdapter.earnWishFulfilledBonus가 이
// 방식으로 설계되어 있었다. 이 라우트는 그 흐름을 서버 상태 갱신과
// 하나의 트랜잭션으로 묶는 역할).
//
// [절대 원칙] 지급 + 상태갱신은 반드시 하나의 $transaction으로 처리한다.
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
      const wish = await tx.wish.findUnique({ where: { id: dbId } });
      if (!wish || wish.deletedAt != null) {
        throw new Error("WISH_NOT_FOUND");
      }
      if (wish.userId !== auth.userId) {
        throw new Error("NOT_OWNER");
      }

      // 이미 fulfilled 상태면 재지급 없이 현재 상태 그대로 반환한다
      // (idempotent — Detail 화면에서 실수로 두 번 눌러도 안전).
      if (wish.wishState === "fulfilled") {
        return { wish, grantedAmount: 0 };
      }

      const updated = await tx.wish.update({
        where: { id: dbId },
        data: {
          wishState: "fulfilled",
          fulfilledAt: new Date(),
          // [기존 achievedAt 재사용] toWishDto()의 isGratitude는 achievedAt
          // 유무로 판정한다. wishState 필드 도입으로 판정 축이 하나 더
          // 생겼지만, 기존 "감사 기록" 표시 로직을 깨지 않기 위해
          // achievedAt도 함께 채워 두 신호가 항상 일치하도록 한다.
          achievedAt: wish.achievedAt ?? new Date(),
        },
      });

      // sourceId=wishId 기반 "건당 1회" 판정(dailyLimit 무관). 이미
      // 이 wish로 지급받은 이력이 있으면 eligible=false.
      const eligibility = await checkPolicyEligibility(tx, auth.userId, "wish_fulfilled", {
        scope: "daily",
        sourceId: wish.id,
      });

      let grantedAmount = 0;
      if (eligibility.eligible) {
        const policy = await tx.pointPolicy.findUnique({
          where: { sourceType: "wish_fulfilled" },
        });
        const amount = policy?.amount ?? 0;
        if (amount > 0) {
          const outcome = await earnLuckPouch(tx, {
            userId: auth.userId,
            amount,
            sourceType: "wish_fulfilled",
            sourceId: wish.id,
            memo: "소원 성취 축하",
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
        { success: false, error: "본인의 소원만 성취로 표시할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    console.error("[PATCH /api/public/wishes/:id/fulfilled] 실패:", e);
    return NextResponse.json(
      { success: false, error: "성취 처리에 실패했습니다." },
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
