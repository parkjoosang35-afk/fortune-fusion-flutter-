// 공개(비인증) 소원방 상점 카탈로그 조회 API — 테마/오브젝트 목록 + 해당 유저의
// 보유(ownership)/장착(placement) 여부를 함께 내려준다(프론트에서 "구매완료"/"장착중"
// 뱃지를 즉시 표시할 수 있도록). 가격 등 정책값은 전부 서버 마스터 데이터 기준이며
// 클라이언트가 재계산하지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, corsOptionsResponse } from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const [themes, objects, inventory, placements] = await Promise.all([
      prisma.wishRoomTheme.findMany({ where: { isActive: true, deletedAt: null }, orderBy: { displayOrder: "asc" } }),
      prisma.wishRoomObject.findMany({ where: { isActive: true, deletedAt: null }, orderBy: { displayOrder: "asc" } }),
      prisma.wishRoomInventory.findMany({ where: { userId } }),
      prisma.wishRoomPlacement.findMany({ where: { userId } }),
    ]);

    const ownedKey = (t: string, id: number) => `${t}:${id}`;
    const ownedSet = new Set(inventory.map((i) => ownedKey(i.itemType, i.itemId)));
    const placedSet = new Set(placements.map((p) => ownedKey(p.itemType, p.itemId)));

    const themeList = themes.map((t) => ({
      id: t.id,
      name: t.name,
      previewImageUrl: t.previewImageUrl,
      backgroundAssetUrl: t.backgroundAssetUrl,
      animationAssetUrl: t.animationAssetUrl,
      pouchPrice: t.pouchPrice,
      isPurchasable: t.isPurchasable,
      isEventOnly: t.isEventOnly,
      owned: t.pouchPrice === 0 || ownedSet.has(ownedKey("theme", t.id)),
      applied: placedSet.has(ownedKey("theme", t.id)),
    }));

    const objectList = objects.map((o) => ({
      id: o.id,
      name: o.name,
      category: o.category,
      imageUrl: o.imageUrl,
      animationAssetUrl: o.animationAssetUrl,
      pouchPrice: o.pouchPrice,
      unlockType: o.unlockType,
      unlockThreshold: o.unlockThreshold,
      isEventOnly: o.isEventOnly,
      owned: o.pouchPrice === 0 || ownedSet.has(ownedKey("object", o.id)),
      applied: placedSet.has(ownedKey("object", o.id)),
    }));

    return NextResponse.json(
      { success: true, data: { themes: themeList, objects: objectList } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/wish-room/catalog] 실패:", e);
    return NextResponse.json({ success: false, error: "카탈로그 조회에 실패했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("GET");
}
