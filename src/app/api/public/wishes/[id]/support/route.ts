// 소원 응원 API — WishWallRepository.support() 대응.
//
// [사용자 확정 원칙] 현재 스키마에는 "어떤 유저가 어떤 Wish를 응원했는지"
// 기록하는 테이블이 없다(Like 모델이 @@unique([targetType, targetId, userId])로
// wish 타입을 구조상 지원하지만 실제 사용 코드는 0건임을 확인함).
// 이번 6-1 단계에서는 임의로 새 테이블/필드를 만들지 않고, 지시받은 대로
// supportCount + 1만 수행한다(중복 방지 없음 — 후속 정책 작업으로 이관).
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

export async function POST(
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
    if (existing.status !== "visible" && existing.status !== "gratitude") {
      return NextResponse.json(
        { success: false, error: "응원할 수 없는 소원입니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const updated = await prisma.wish.update({
      where: { id: dbId },
      data: { supportCount: { increment: 1 } },
      include: { user: { select: { nickname: true } } },
    });

    const dto = toWishDto(updated as unknown as WishRow, auth.userId);
    return NextResponse.json({ success: true, data: dto }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/wishes/:id/support] 실패:", e);
    return NextResponse.json(
      { success: false, error: "응원 처리에 실패했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
