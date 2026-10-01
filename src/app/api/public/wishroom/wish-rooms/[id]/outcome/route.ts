// 타임캡슐 결과 선택 — Flutter WrRepository.outcome() 대응.
// [원본] app/api.js C2 · POST /wish-rooms/{id}/outcome { outcome, text?, sealUntil? }.
// FULFILLED: 완료 처리(idempotent — 이미 ACHIEVED면 그대로 반환). ONGOING: 진행중 유지.
// REWISH: 같은 방에서 새 문구·새 봉인일로 다시 봉인(capsule=LOCKED, outcome 리셋).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { buildRoomView, checkSealDate, filterText, WishRoomError } from "@/lib/wishroom-engine";
import { createNotification } from "@/lib/notification-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, wrNotificationDeepLink } from "../../../_shared";

export const dynamic = "force-dynamic";

const VALID_OUTCOMES = ["FULFILLED", "ONGOING", "REWISH"];

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { outcome?: string; text?: string; sealUntil?: string; force?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const view = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "방 주인만 고를 수 있어요");
      if (room.capsule !== "OPENED") throw new WishRoomError(409, "NOT_OPENED", "먼저 소원을 열어주세요");
      if (!body.outcome || !VALID_OUTCOMES.includes(body.outcome)) {
        throw new WishRoomError(400, "INVALID", "어떻게 되었는지 골라주세요");
      }

      // 중복 클릭·재전송 → idempotent (이미 ACHIEVED면 그대로 반환)
      if (body.outcome === "FULFILLED" && room.wishStatus === "ACHIEVED") {
        return buildRoomView(tx, room, auth.userId);
      }

      const data: {
        wishStatus?: string;
        status?: string;
        completedAt?: Date;
        outcome: string | null;
        text?: string;
        sealUntil?: string;
        capsule?: string;
        unsealNotified?: boolean;
      } = { outcome: body.outcome };

      if (body.outcome === "FULFILLED") {
        const nowDate = new Date();
        data.wishStatus = "ACHIEVED";
        data.status = "COMPLETED";
        data.completedAt = nowDate;
        await createNotification(tx, {
          userId: auth.userId,
          category: "community",
          title: "소중한 소원이 이루어졌어요.",
          body: "소중한 소원이 이루어졌어요.",
          deepLink: wrNotificationDeepLink(dbId, "COMPLETE"),
        });
      }
      if (body.outcome === "ONGOING") {
        data.wishStatus = "IN_PROGRESS";
      }
      if (body.outcome === "REWISH") {
        if (body.text) {
          filterText(body.text, !!body.force);
          data.text = body.text.trim().slice(0, 100);
        }
        data.sealUntil = checkSealDate(body.sealUntil);
        data.capsule = "LOCKED";
        data.unsealNotified = false;
        data.outcome = null;
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
