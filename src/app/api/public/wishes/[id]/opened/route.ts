// 소원함 개봉(Box Opening) 완료 기록 API — bokjumeoni-plan §03 SERVER API
// `PATCH /wishes/:id/opened` 대응.
//
// [역할] 07 Box Opening 화면을 실제로 다 봤을 때 서버 openedBoxAt을
// 기록한다. 이렇게 해야 GET /wishes/pending-openings가 다시는 같은 소원을
// 후보로 돌려주지 않는다(Phase01의 SharedPreferences 로컬 기록을 서버
// 원장으로 승격 — 기기를 바꿔도 유지되고, 관리자가 원장을 확인할 수 있음).
//
// [주의] 이 API는 복주머니를 지급하지 않는다(지급은 이미 Flutter가
// BlessingBagPolicyAdapter.earnWeeklyBoxOpeningBonus()를 통해 별도로
// 처리 중 — /wallet/earn 경유). 이 API는 순수하게 "봤음" 표시만 담당한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
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
    const existing = await prisma.wish.findUnique({ where: { id: dbId } });
    if (!existing || existing.deletedAt != null) {
      return NextResponse.json(
        { success: false, error: "소원을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    // 본인 소원만 "개봉 완료" 처리를 할 수 있다(타인의 pending-openings에
    // 영향을 줄 수 없어야 함).
    if (existing.userId !== auth.userId) {
      return NextResponse.json(
        { success: false, error: "본인의 소원만 개봉 처리할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // 이미 openedBoxAt이 있으면 값을 덮어쓰지 않고 그대로 반환한다
    // (idempotent — 같은 소원에 대해 여러 번 호출돼도 최초 시각을 유지).
    const updated = existing.openedBoxAt
      ? existing
      : await prisma.wish.update({
          where: { id: dbId },
          data: { openedBoxAt: new Date() },
        });

    const withUser = await prisma.wish.findUnique({
      where: { id: updated.id },
      include: { user: { select: { nickname: true } } },
    });

    const dto = toWishDto(withUser as unknown as WishRow, auth.userId);
    return NextResponse.json({ success: true, data: dto }, { headers: CORS_HEADERS });
  } catch (e) {
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
