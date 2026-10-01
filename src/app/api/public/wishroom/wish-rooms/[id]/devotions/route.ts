// 정성 들이기 — Flutter WrRepository.devote() 대응. [SERVER] 일일 한도/쿨타임 서버 재검증.
// [원본] app/api.js 라우트 4 · POST /wish-rooms/{id}/devotions.
// 하루 10회(아이템 fx.daily 보정) + 30초 쿨타임(fx.cool 보정). 10회째 도달 시
// +20(+fx.pouch) 복주머니 보너스(1일 1회, idempotent via earnLog 근사 — 여기서는
// devotionsToday===bonusAt 시점에만 트리거되므로 자연히 1회만 발생).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, calcPoints, effectsOf, kstDate, levelOf, parseEquip, WishRoomError, WR } from "@/lib/wishroom-engine";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { createNotification } from "@/lib/notification-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, toWishRoomPublicId, buildMeView } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 정성을 들일 수 있어요");
      if (!["ACTIVE", "GROWING"].includes(room.status)) throw new WishRoomError(409, "INVALID_STATE", "지금은 정성을 들일 수 없어요");

      const nowMs = Date.now();
      const today = kstDate(nowMs);
      const devoToday = room.devotionsResetDate === today ? room.devotionsToday : 0;

      const equip = parseEquip(room.equipJson);
      const fx = effectsOf(equip, room.wishColor);
      const dailyLimit = WR.DEVOTION_RULE.dailyLimit + fx.daily;
      const cooldownSec = WR.DEVOTION_RULE.cooldownSec - fx.cool;

      if (devoToday >= dailyLimit) {
        throw new WishRoomError(429, "DAILY_LIMIT", "오늘의 정성은 모두 담았어요. 내일 다시 밝혀주세요");
      }
      if (room.lastDevotionAt && nowMs - room.lastDevotionAt.getTime() < cooldownSec * 1000) {
        const retryAfter = Math.ceil((room.lastDevotionAt.getTime() + cooldownSec * 1000 - nowMs) / 1000);
        throw new WishRoomError(429, "COOLDOWN", "촛불이 정성을 머금는 중이에요", { retryAfter });
      }

      const prevLevel = room.level;
      const newDevoToday = devoToday + 1;
      const gainBonus = Number((fx.devo / 100).toFixed(2));
      const newBonusPts = Number((room.bonusPts + gainBonus).toFixed(2));
      const newDevotionCount = room.devotionCount + 1;
      const newPoints = calcPoints({ devotionCount: newDevotionCount, supportCount: room.supportCount, pouchReceived: room.pouchReceived, bonusPts: newBonusPts });
      const newLevel = levelOf(newPoints);
      const newStatus = room.status === "ACTIVE" ? "GROWING" : room.status;

      const updated = await tx.wishRoom.update({
        where: { id: room.id },
        data: {
          devotionsToday: newDevoToday,
          devotionsResetDate: today,
          devotionCount: newDevotionCount,
          lastDevotionAt: new Date(nowMs),
          lastActiveAt: new Date(nowMs),
          bonusPts: newBonusPts,
          points: newPoints,
          level: newLevel,
          status: newStatus,
        },
        include: { user: { select: { nickname: true } } },
      });

      let bonus = 0;
      if (newDevoToday === WR.DEVOTION_RULE.bonusAt) {
        const already = await tx.wishRoomEarnLog.findFirst({ where: { userId: auth.userId, source: "devo10", dateKey: today } });
        if (!already) {
          bonus = WR.DEVOTION_RULE.bonusPouch + fx.pouch;
          await earnLuckPouch(tx, {
            userId: auth.userId,
            amount: bonus,
            sourceType: "wishroom_devotion_bonus",
            sourceId: room.id,
            memo: `정성 10회 완료 보너스${fx.pouch ? ` (+${fx.pouch} 기운)` : ""}`,
          });
          await tx.wishRoomEarnLog.create({ data: { userId: auth.userId, source: "devo10", amount: bonus, dateKey: today } });
        }
      }

      const leveledUp = newLevel > prevLevel;
      if (leveledUp) {
        await createNotification(tx, {
          userId: auth.userId,
          category: "community",
          title: "소원방 성장",
          body: `소원방이 Lv.${newLevel} 로 성장했어요.`,
          deepLink: `wishroom:${toWishRoomPublicId(room.id)}`,
        });
      }

      const roomView = await buildRoomView(tx, updated, auth.userId, nowMs);
      const me = await buildMeView(tx, auth.userId, nowMs);

      return {
        room: roomView,
        prevLevel,
        leveledUp,
        bonus,
        gain: { base: 1, bonus: gainBonus, fx: fx.src },
        me,
      };
    });

    return NextResponse.json({ success: true, data }, { status: 202, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
