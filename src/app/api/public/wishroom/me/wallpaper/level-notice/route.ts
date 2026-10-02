// W5 · POST /me/wallpaper/level-notice — S-07 레벨업 연출 안내를 1회 보여준 뒤 기록.
// [원본] app/api.js 601줄 · db.me.wallpaper.seenLevelNotice = b.level 포팅.
// 배경화면을 설정한 적이 없으면(= wallpaperRoomId null) 조용히 무시한다(app2/fx2.jsx
// LevelUp()도 .catch(()=>{})로 에러를 무시하는 선례와 동일 — 연출을 막을 이유가 없음).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildWallpaperStatusView } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, getOrCreateUserState } from "../../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { level?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const state = await getOrCreateUserState(tx, auth.userId);
      if (state.wallpaperRoomId == null || !body.level) {
        return buildWallpaperStatusView(tx, state);
      }
      const updated = await tx.wishRoomUserState.update({
        where: { userId: auth.userId },
        data: { wallpaperSeenLevelNotice: body.level },
      });
      return buildWallpaperStatusView(tx, updated);
    });
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
