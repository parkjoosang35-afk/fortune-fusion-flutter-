// 소원방 단건 조회/수정 — Flutter WrRepository.room()/updateRoom() 대응.
// [원본] app/api.js 라우트 3(GET) · 보조(PATCH, 공개범위·DRAFT 편집).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, filterText, kstDate, WishRoomError } from "@/lib/wishroom-engine";
import { parseWishRoomDbId, requireUser, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse } from "../../_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const { searchParams } = new URL(request.url);
  const via = searchParams.get("via");

  const auth = await requireUser(request);

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) {
        throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      }
      const isMine = room.userId === auth?.userId;
      if (!isMine && room.visibility === "PRIVATE") {
        throw new WishRoomError(403, "PRIVATE", "비공개 소원방이에요");
      }
      if (!isMine && room.visibility === "LINK" && via !== room.shareToken) {
        throw new WishRoomError(403, "LINK_ONLY", "링크를 받은 분만 볼 수 있어요");
      }
      // [버그수정 — 전수감사] 미션 04 "다른 소원방 3곳 둘러보기" 실제 행동 기록.
      // 로그인 상태로 "남의" 방을 열람할 때만 기록(자기 방 반복 조회는 미션과 무관).
      if (auth && !isMine) {
        const dateKey = kstDate();
        await tx.wishRoomVisit.upsert({
          where: { roomId_userId_dateKey: { roomId: dbId, userId: auth.userId, dateKey } },
          create: { roomId: dbId, userId: auth.userId, dateKey },
          update: {},
        });
      }
      return buildRoomView(tx, room, auth?.userId ?? null);
    });
    return NextResponse.json({ success: true, data: view }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) {
    return NextResponse.json({ success: false, error: "로그인이 필요합니다.", code: "UNAUTHORIZED" }, { status: 401, headers: CORS_HEADERS });
  }

  let body: { visibility?: "PUBLIC" | "LINK" | "PRIVATE"; text?: string; force?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId } });
      if (!room || room.deletedAt != null) {
        throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      }
      if (room.userId !== auth.userId) {
        throw new WishRoomError(403, "NOT_OWNER", "방 주인만 바꿀 수 있어요");
      }

      const data: { visibility?: string; text?: string } = {};
      if (body.visibility) data.visibility = body.visibility;
      if (body.text != null) {
        if (room.status !== "DRAFT") {
          throw new WishRoomError(409, "LOCKED", "확정된 소원 문구는 바꿀 수 없어요");
        }
        filterText(body.text, !!body.force);
        data.text = body.text;
      }

      const updated = await tx.wishRoom.update({
        where: { id: dbId },
        data,
        include: { user: { select: { nickname: true } } },
      });
      return buildRoomView(tx, updated, auth.userId);
    });
    return NextResponse.json({ success: true, data: view }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
