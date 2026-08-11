// 공개(비인증) 소원방 꾸미기 적용 API — 보유(WishRoomInventory) 중인 테마/오브젝트를
// 실제 장착 상태(WishRoomPlacement)로 전환하거나 해제한다.
//
// [소유 검증] 구매/획득하지 않은 아이템은 장착할 수 없다(§ "관리자 설정값 하드코딩
// 금지"와 별개로, 클라이언트가 미보유 아이템을 임의 장착하는 것도 금지). 단, 가격이
// 0원(pouchPrice=0)인 기본 제공 아이템은 최초 장착 시 자동으로 보유 처리한다(무료
// 기본값은 별도 구매 절차 없이 즉시 사용 가능해야 하므로).
//
// [슬롯 규칙] slotKey는 아이템 종류로부터 서버가 결정한다(클라이언트가 슬롯을 지정하지
// 않음) — theme 아이템은 항상 slotKey="theme", object 아이템은 category를 그대로
// slotKey로 사용한다(star_effect/moon_effect/orb_effect/special_animation/decoration).
// decoration 슬롯만 다중 장착을 허용하고, 그 외 단일 슬롯은 기존 장착을 교체(delete
// 후 insert)한다. energy_charge(에너지 충전권)는 소모성 아이템이라 배치 대상이 아니다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, corsOptionsResponse } from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

const SINGLE_SLOTS = new Set(["theme", "star_effect", "moon_effect", "orb_effect", "special_animation"]);

interface ApplyBody {
  userId?: number;
  itemType?: string; // "theme" | "object"
  itemId?: number;
  action?: string; // "apply" | "remove", 기본 apply
}

export async function POST(request: NextRequest) {
  let body: ApplyBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  const userId = Number(body.userId ?? 1);
  const itemType = body.itemType;
  const itemId = Number(body.itemId);
  const action = body.action === "remove" ? "remove" : "apply";

  if (itemType !== "theme" && itemType !== "object") {
    return NextResponse.json({ success: false, error: "itemType은 theme 또는 object여야 합니다." }, { status: 400, headers: CORS_HEADERS });
  }
  if (!Number.isInteger(itemId)) {
    return NextResponse.json({ success: false, error: "itemId가 올바르지 않습니다." }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 1) 아이템 마스터 조회 — slotKey 결정 + 무료 자동보유 판단용.
      let slotKey: string;
      let price: number;
      if (itemType === "theme") {
        const theme = await tx.wishRoomTheme.findUnique({ where: { id: itemId } });
        if (!theme || theme.deletedAt || !theme.isActive) throw new Error("ITEM_NOT_FOUND");
        slotKey = "theme";
        price = theme.pouchPrice;
      } else {
        const obj = await tx.wishRoomObject.findUnique({ where: { id: itemId } });
        if (!obj || obj.deletedAt || !obj.isActive) throw new Error("ITEM_NOT_FOUND");
        if (obj.category === "energy_charge") throw new Error("NOT_PLACEABLE");
        slotKey = obj.category;
        price = obj.pouchPrice;
      }

      if (action === "remove") {
        await tx.wishRoomPlacement.deleteMany({ where: { userId, slotKey, itemType, itemId } });
        const placements = await tx.wishRoomPlacement.findMany({ where: { userId } });
        return { placements, slotKey };
      }

      // 2) 소유 검증(회원간 데이터 격리 — userId로 항상 필터링). 무료(0원) 아이템은
      // 최초 장착 시 자동 보유 처리한다.
      let owned = await tx.wishRoomInventory.findUnique({
        where: { userId_itemType_itemId: { userId, itemType, itemId } },
      });
      if (!owned) {
        if (price > 0) throw new Error("NOT_OWNED");
        owned = await tx.wishRoomInventory.create({ data: { userId, itemType, itemId, acquiredVia: "auto_free" } });
      }

      // 3) 단일 슬롯은 교체(기존 장착 제거 후 신규 삽입), decoration은 다중 허용.
      if (SINGLE_SLOTS.has(slotKey)) {
        await tx.wishRoomPlacement.deleteMany({ where: { userId, slotKey } });
      }
      await tx.wishRoomPlacement.upsert({
        where: { userId_slotKey_itemId: { userId, slotKey, itemId } },
        create: { userId, slotKey, itemType, itemId },
        update: { appliedAt: new Date() },
      });

      // theme을 장착한 경우 프로필의 currentThemeId도 함께 갱신(단일 대표 테마).
      if (itemType === "theme") {
        await tx.wishRoomProfile.updateMany({ where: { userId }, data: { currentThemeId: itemId } });
      }

      const placements = await tx.wishRoomPlacement.findMany({ where: { userId } });
      return { placements, slotKey };
    });

    return NextResponse.json(
      { success: true, data: { placements: result.placements, slotKey: result.slotKey, action } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "ITEM_NOT_FOUND") {
      return NextResponse.json({ success: false, error: "아이템을 찾을 수 없습니다." }, { status: 404, headers: CORS_HEADERS });
    }
    if (message === "NOT_OWNED") {
      return NextResponse.json({ success: false, error: "보유하지 않은 아이템입니다.", reason: "NOT_OWNED" }, { status: 409, headers: CORS_HEADERS });
    }
    if (message === "NOT_PLACEABLE") {
      return NextResponse.json({ success: false, error: "장착할 수 없는 아이템입니다.", reason: "NOT_PLACEABLE" }, { status: 409, headers: CORS_HEADERS });
    }
    console.error("[POST /api/wish-room/customize/apply] 실패:", e);
    return NextResponse.json({ success: false, error: "꾸미기 적용에 실패했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
