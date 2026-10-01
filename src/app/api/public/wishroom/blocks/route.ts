// 차단 — Flutter WrRepository.block(String userId) 대응.
// [원본] app/api.js §15 · POST /blocks { userId }.
// Flutter 쪽 userId는 접두사 없이 순수 숫자 문자열(roomView의 ownerId: String(r.userId)와
// 동일 컨벤션) — WishRoomBlock(blockerId, blockedId) 레코드를 생성한다(이미 존재하면 idempotent).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { userId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  const blockedId = Number(body.userId);
  if (!Number.isFinite(blockedId) || !Number.isInteger(blockedId)) {
    return NextResponse.json({ success: false, error: "userId가 올바르지 않습니다.", code: "INVALID" }, { status: 400, headers: CORS_HEADERS });
  }
  if (blockedId === auth.userId) {
    return NextResponse.json({ success: false, error: "자기 자신은 차단할 수 없어요", code: "SELF" }, { status: 403, headers: CORS_HEADERS });
  }

  try {
    await prisma.$transaction(async (tx) => {
      const target = await tx.user.findUnique({ where: { id: blockedId }, select: { id: true } });
      if (!target) throw new WishRoomError(404, "NOT_FOUND", "사용자를 찾을 수 없어요");

      await tx.wishRoomBlock.upsert({
        where: { blockerId_blockedId: { blockerId: auth.userId, blockedId } },
        create: { blockerId: auth.userId, blockedId },
        update: {},
      });
    });

    return NextResponse.json({ success: true, data: { blocked: String(blockedId) } }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
