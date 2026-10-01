// 공유 링크 발급 — Flutter WrRepository.shareLink() 대응.
// [원본] app/api.js S1 · POST /wish-rooms/{id}/share-link { reissue? }.
// 방마다 토큰 1개. reissue=true거나 아직 토큰이 없으면 새로 발급(이전 토큰은 즉시 무효).
import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { prisma } from "@/lib/db";
import { WishRoomError } from "@/lib/wishroom-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId } from "../../../_shared";

export const dynamic = "force-dynamic";

function genToken(): string {
  return randomBytes(6).toString("base64url").slice(0, 8);
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { reissue?: boolean };
  try {
    body = await request.json().catch(() => ({}));
  } catch {
    body = {};
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 링크를 만들 수 있어요");
      if (room.visibility === "PRIVATE") throw new WishRoomError(409, "PRIVATE", "나만 보기 소원방은 공유할 수 없어요");

      let token = room.shareToken;
      if (!token || body.reissue) {
        // 토큰 충돌 가능성은 희박하지만(6바이트 base64url) 방어적으로 재시도 루프.
        for (let i = 0; i < 5; i++) {
          const candidate = genToken();
          const exists = await tx.wishRoom.findUnique({ where: { shareToken: candidate }, select: { id: true } });
          if (!exists) {
            token = candidate;
            break;
          }
        }
        if (!token) throw new WishRoomError(500, "TOKEN_GEN_FAILED", "링크 생성에 실패했어요");
        await tx.wishRoom.update({ where: { id: dbId }, data: { shareToken: token } });
      }

      return { token, url: `https://sintong.kr/w/${token}`, visibility: room.visibility };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
