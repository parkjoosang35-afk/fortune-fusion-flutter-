// 공개(비인증) 소원방(Wish Room) 조회 API — Flutter WishRoomPage 최초 진입 시 호출.
//
// [설계] 이 API는 부수효과를 가진다(단순 조회가 아님):
//   1) 방문 카운트/연속방문일수 갱신(touchVisit) — 소원방 재방문 스트릭 계산의 유일한 지점.
//   2) 각 소원의 미접속 감쇠(applyDecayIfNeeded) 적용 — 마지막 돌봄 이후 경과일 기준.
// 두 부수효과 모두 GET이지만 "입장" 행위 자체가 상태 변화를 유발하는 소원방의
// 도메인 특성상 의도된 것이다(§ 사용자 요구사항 "입장 시 감쇠 계산, 미접속 시
// 에너지만 감소").
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  getOrCreateWishRoomProfile,
  touchVisit,
  applyDecayIfNeeded,
  serializeProfile,
  serializeWish,
  listActiveCategories,
  getWishRoomConfigBool,
  getWishRoomConfigNumber,
  CORS_HEADERS,
  corsOptionsResponse,
} from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 1) 회원별 데이터 격리 — 이 트랜잭션 내 모든 쿼리는 userId로만 필터링된다.
      const profile = await touchVisit(tx, userId);

      // 2) 보유 소원 전체를 가져와 감쇠를 적용한다.
      const wishes = await tx.wishRoomWish.findMany({
        where: { userId, status: "active" },
        orderBy: [{ isRepresentative: "desc" }, { createdAt: "asc" }],
      });

      const decayedWishes = [];
      for (const w of wishes) {
        const { energyAfter } = await applyDecayIfNeeded(tx, w);
        decayedWishes.push({ ...w, energy: energyAfter });
      }

      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });

      const inventory = await tx.wishRoomInventory.findMany({ where: { userId } });
      const placements = await tx.wishRoomPlacement.findMany({ where: { userId } });

      return { profile, wishes: decayedWishes, wallet, inventory, placements };
    });

    const [categories, maxWishCount, careDailyFreeCount, entryAnimEnabled, guideAutoShow] = await Promise.all([
      listActiveCategories(),
      getWishRoomConfigNumber("wish_room_max_wish_count", 3),
      getWishRoomConfigNumber("wish_room_care_daily_free_count", 1),
      getWishRoomConfigBool("wish_room_entry_animation_enabled", true),
      getWishRoomConfigBool("wish_room_guide_auto_show_on_first_visit", true),
    ]);

    return NextResponse.json(
      {
        success: true,
        data: {
          profile: serializeProfile(result.profile),
          wishes: result.wishes.map(serializeWish),
          pouchBalance: result.wallet?.balance ?? 0,
          inventory: result.inventory.map((i) => ({
            itemType: i.itemType,
            itemId: i.itemId,
            acquiredVia: i.acquiredVia,
          })),
          placements: result.placements.map((p) => ({
            slotKey: p.slotKey,
            itemType: p.itemType,
            itemId: p.itemId,
          })),
          categories: categories.map((c) => ({
            code: c.code,
            label: c.label,
            emoji: c.emoji,
            colorHex: c.colorHex,
          })),
          policy: {
            maxWishCount,
            careDailyFreeCount,
            entryAnimationEnabled: entryAnimEnabled,
            guideAutoShowOnFirstVisit: guideAutoShow && !result.profile.hasSeenGuide,
          },
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[GET /api/wish-room/me] 실패:", e);
    return NextResponse.json(
      { success: false, error: "소원방 정보를 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("GET");
}
