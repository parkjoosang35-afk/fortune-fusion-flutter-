// W2/W3/W4 · GET·PUT·DELETE /me/wallpaper — 배경화면 설정 상태(docs/WALLPAPER.md §2).
// [원본] app/api.js 587-599줄 · db.me.wallpaper 포팅 → WishRoomUserState.wallpaper_* 컬럼.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildWallpaperStatusView, WishRoomError } from "@/lib/wishroom-engine";
import { parseWishRoomDbId, requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getOrCreateUserState } from "../../_shared";

export const dynamic = "force-dynamic";

// W2 — 현재 설정 상태 + 업데이트 필요 여부(S-01 배지 · S-02 상태 카드).
export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const data = await prisma.$transaction(async (tx) => {
      const state = await getOrCreateUserState(tx, auth.userId);
      return buildWallpaperStatusView(tx, state);
    });
    // [SERVER] 설정한 적 없으면 null — Flutter WallpaperStatus.fromJson이 null을 받으면
    // ApiRepository 쪽에서 empty()로 다루도록 data 자체를 null로 내려준다(app/api.js와 동일).
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

// W3 — 설정 기록 {roomId, platform: android|ios, target: BOTH|HOME|LOCK, version}.
export async function PUT(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { roomId?: string; platform?: string; target?: string; version?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      if (!body.roomId) throw new WishRoomError(400, "BAD_REQUEST", "roomId가 필요해요");
      const dbId = parseWishRoomDbId(body.roomId);
      if (dbId === null) throw new WishRoomError(400, "INVALID_ID", "방 id가 올바르지 않습니다.");

      const room = await tx.wishRoom.findUnique({ where: { id: dbId } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "내 소원방만 배경화면으로 쓸 수 있어요");

      await getOrCreateUserState(tx, auth.userId);
      const state = await tx.wishRoomUserState.update({
        where: { userId: auth.userId },
        data: {
          wallpaperRoomId: dbId,
          wallpaperPlatform: body.platform ?? "android",
          wallpaperTarget: body.target ?? "BOTH",
          wallpaperVersion: body.version ?? room.wpVersion ?? 1,
          wallpaperSeenLevelNotice: room.level,
        },
      });
      return buildWallpaperStatusView(tx, state);
    });
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

// W4 — 해제(Android에서 다른 배경을 고른 것이 감지될 때).
export async function DELETE(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    await prisma.$transaction(async (tx) => {
      await getOrCreateUserState(tx, auth.userId);
      await tx.wishRoomUserState.update({
        where: { userId: auth.userId },
        data: { wallpaperRoomId: null, wallpaperPlatform: null, wallpaperTarget: null, wallpaperVersion: 0, wallpaperSeenLevelNotice: 0 },
      });
    });
    return new NextResponse(null, { status: 204, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
