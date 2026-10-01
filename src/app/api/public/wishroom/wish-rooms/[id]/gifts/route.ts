// 복주머니 보내기 — Flutter WrRepository.gift() 대응. [SERVER]
// [원본] app/api.js 라우트 7 · POST /wish-rooms/{id}/gifts.
// 자기 방 불가, 가입 7일 미만은 하루 100개 한도. spendLuckPouch로 실제 지갑 차감
// (기존 wishes/[id]/bokju/route.ts와 동일 트랜잭션 패턴: 조회→검증→spend→DB반영).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, calcPoints, daysBetween, kstDate, levelOf, WishRoomError } from "@/lib/wishroom-engine";
import { spendLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, buildMeView } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { amount?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId === auth.userId) throw new WishRoomError(403, "SELF", "내 소원방에는 복주머니를 보낼 수 없어요");

      const amount = Math.floor(body.amount ?? 0);
      if (amount <= 0) throw new WishRoomError(400, "INVALID", "보낼 수량을 정해주세요");

      const nowMs = Date.now();
      const today = kstDate(nowMs);

      const user = await tx.user.findUnique({ where: { id: auth.userId }, select: { createdAt: true } });
      const accountAgeDays = user ? daysBetween(user.createdAt, new Date(nowMs)) : 0;

      if (accountAgeDays < 7) {
        const sentAgg = await tx.wishRoomGift.aggregate({ where: { senderId: auth.userId, dateKey: today }, _sum: { amount: true } });
        const sent = sentAgg._sum.amount ?? 0;
        if (sent + amount > 100) {
          throw new WishRoomError(429, "NEW_ACCOUNT_LIMIT", `가입 7일 전에는 하루 100개까지 보낼 수 있어요 (오늘 ${sent}개)`);
        }
      }

      const spendResult = await spendLuckPouch(tx, {
        userId: auth.userId,
        amount,
        sourceType: "wishroom_gift_sent",
        sourceId: room.id,
        memo: room.region ? `${room.region} · 소원방` : "복주머니 선물",
      });
      if (!spendResult.ok) throw new WishRoomError(402, "INSUFFICIENT", "복주머니가 부족해요", { need: amount, have: spendResult.balanceAfter ?? 0 });

      await tx.wishRoomGift.create({ data: { roomId: dbId, senderId: auth.userId, amount, dateKey: today } });

      const newPouchReceived = room.pouchReceived + amount;
      const newPoints = calcPoints({ devotionCount: room.devotionCount, supportCount: room.supportCount, pouchReceived: newPouchReceived, bonusPts: room.bonusPts });
      const newLevel = levelOf(newPoints);

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data: { pouchReceived: newPouchReceived, points: newPoints, level: newLevel },
        include: { user: { select: { nickname: true } } },
      });

      const roomView = await buildRoomView(tx, updated, auth.userId, nowMs);
      const me = await buildMeView(tx, auth.userId, nowMs);
      return { room: roomView, me };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
