// V1 · 성취 후기 등록 — Flutter WrRepository.postReview() 대응.
// [원본] app/api.js V1 · POST /wish-rooms/{id}/review { text, photo?, visibility }.
// 내 소원 + ACHIEVED 상태에서만 등록 가능. 재전송(이미 후기 있음)은 같은 후기를
// duplicate:true로 그대로 반환하고 재지급하지 않는다(idempotent). 어뷰징 플래그가
// 있으면 status="review"(보상 보류 + 관리자 검토), 없으면 즉시 복주머니 보상 지급.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { filterText, reviewAbuseFlags, WishRoomError } from "@/lib/wishroom-engine";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, parseWishRoomDbId, toWishRoomReviewPublicId, buildMeView } from "../../../_shared";

export const dynamic = "force-dynamic";

const STATUS_TO_FE: Record<string, string> = {
  visible: "OK",
  review: "REVIEW",
  hidden_by_report: "HIDDEN",
  deleted_by_admin: "DELETED",
};

function toReviewDto(
  v: {
    id: number;
    roomId: number;
    userId: number;
    text: string;
    photoUrl: string | null;
    wishColor?: string;
    congratsCount: number;
    status: string;
    user?: { nickname: string } | null;
  },
  authorNickname: string,
  wishText: string,
  congratsByMe: boolean,
  isMine: boolean
) {
  return {
    id: toWishRoomReviewPublicId(v.id),
    roomId: String(v.roomId),
    author: v.user?.nickname ?? authorNickname,
    wishText,
    text: v.text,
    wishColor: v.wishColor ?? "hope",
    photo: v.photoUrl,
    congrats: v.congratsCount,
    congratsByMe,
    mine: isMine,
    status: STATUS_TO_FE[v.status] ?? "OK",
  };
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const dbId = parseWishRoomDbId(id);
  if (dbId === null) {
    return NextResponse.json({ success: false, error: "방 id가 올바르지 않습니다.", code: "INVALID_ID" }, { status: 400, headers: CORS_HEADERS });
  }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { text?: string; photo?: string; visibility?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const room = await tx.wishRoom.findUnique({ where: { id: dbId }, include: { user: { select: { nickname: true } } } });
      if (!room || room.deletedAt != null) throw new WishRoomError(404, "NOT_FOUND", "소원방을 찾을 수 없어요");
      if (room.userId !== auth.userId) throw new WishRoomError(403, "NOT_OWNER", "내 소원에만 후기를 남길 수 있어요");
      if (room.wishStatus !== "ACHIEVED") throw new WishRoomError(409, "NOT_ACHIEVED", "이루어진 소원에만 후기를 남길 수 있어요");

      const existing = await tx.wishRoomReview.findFirst({ where: { roomId: dbId, deletedAt: null }, include: { user: { select: { nickname: true } } } });
      if (existing) {
        const me = await buildMeView(tx, auth.userId);
        return {
          review: toReviewDto(existing, room.user.nickname, room.text, false, true),
          reward: null,
          duplicate: true,
          me,
        };
      }

      const text = (body.text ?? "").trim();
      if (text.replace(/\s/g, "").length < 20) throw new WishRoomError(400, "TOO_SHORT", "20자 이상 적어주세요");
      filterText(text, true);

      const nowMs = Date.now();
      const since = new Date(nowMs - 60_000);
      const [recentTexts, recentCount] = await Promise.all([
        tx.wishRoomReview
          .findMany({ where: { userId: auth.userId, deletedAt: null }, select: { text: true } })
          .then((rows) => rows.map((r) => r.text)),
        tx.wishRoomReview.count({ where: { userId: auth.userId, createdAt: { gte: since } } }),
      ]);
      const flags = reviewAbuseFlags(text, recentTexts, recentCount);
      const status = flags.length ? "review" : "visible";

      const created = await tx.wishRoomReview.create({
        data: {
          roomId: dbId,
          userId: auth.userId,
          text,
          photoUrl: body.photo ?? null,
          visibility: body.visibility === "PUBLIC" ? "PUBLIC" : "PRIVATE",
          status,
          flagsJson: JSON.stringify(flags),
        },
        include: { user: { select: { nickname: true } } },
      });

      let reward: { base: number; photo: number } | null = null;
      if (status === "visible") {
        const base = 30;
        const photoBonus = body.photo ? 20 : 0;
        await earnLuckPouch(tx, { userId: auth.userId, amount: base, sourceType: "wishroom_review", sourceId: room.id, memo: "소원 성취 후기" });
        if (photoBonus) {
          await earnLuckPouch(tx, { userId: auth.userId, amount: photoBonus, sourceType: "wishroom_review_photo", sourceId: room.id, memo: "후기 사진 첨부" });
        }
        await tx.wishRoomReview.update({ where: { id: created.id }, data: { rewardGranted: true } });
        await tx.wishRoom.update({ where: { id: dbId }, data: { reviewRewardGranted: true } });
        reward = { base, photo: photoBonus };
      }

      const me = await buildMeView(tx, auth.userId);
      return {
        review: toReviewDto(created, room.user.nickname, room.text, false, true),
        reward,
        held: status === "review",
        me,
      };
    });

    // duplicate 재전송은 200, 신규 생성은 201 (app/api.js V1 상태코드 그대로 포팅)
    const statusCode = "duplicate" in data && data.duplicate ? 200 : 201;
    return NextResponse.json({ success: true, data }, { status: statusCode, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
