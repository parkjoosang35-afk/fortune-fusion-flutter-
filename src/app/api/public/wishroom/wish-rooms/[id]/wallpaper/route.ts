// W1 · GET /wish-rooms/{id}/wallpaper — 배경화면 매니페스트(docs/WALLPAPER.md §1~3).
// [원본] app/api.js 라우트(577-585줄) · app/wp-manifest.js build(). 내 방만 조회 가능.
// version은 렌더 결과(level·equip·char·완료여부·본문)가 실제로 바뀔 때만 +1한다(§8) —
// Flutter 쪽은 이 매니페스트를 직접 그리지 않고(WPManifest.room을 RoomScene에 그대로
// 넘겨 "같은 좌표"로 그림, models.dart 주석 참고) equippedItemIds/fulfilled/room만 쓴다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, syncWallpaperVersion, WishRoomError } from "@/lib/wishroom-engine";
import { parseWishRoomDbId, requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
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
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "내 소원방만 배경화면으로 쓸 수 있어요");

      const version = await syncWallpaperVersion(tx, room);
      const view = await buildRoomView(tx, room, auth.userId);
      const fulfilled = room.status === "ARCHIVED" || room.status === "COMPLETED";

      return {
        wishRoomId: view.id,
        version,
        title: view.levelName ? `Lv.${view.level} ${view.levelName}` : `Lv.${view.level}`,
        room: view,
        equippedItemIds: [view.equip.CANDLE, view.equip.FLOWER, view.equip.BACKGROUND, view.equip.SPECIAL, ...(view.equip.DECORATION || []), ...(view.equip.SEAL || []), ...(view.equip.THEME || [])].filter((x): x is string => !!x),
        fulfilled,
        state: fulfilled ? "FULFILLED" : room.status,
      };
    });
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
