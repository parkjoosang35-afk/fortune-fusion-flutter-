// 감사 도장 찍기 API — bokjumeoni-plan §03 SERVER API `POST /gratitude/seal` 대응.
//
// body: { sourcePouchId: number } — sourcePouchId는 `PointHistory.id`
// (sourceType='send_pouch', type='spend' 레코드)를 가리킨다.
//
// [용어 정리 — schema.prisma GratitudeSeal 모델 주석 그대로]
//   sender    = 도장을 "찍는" 사람 = 원래 sendPouch를 "받은" 사람 = 그 소원의 주인
//               (auth.userId가 반드시 이 사람이어야 한다 — 본인 소원에 들어온
//               복주머니에만 답례할 수 있다)
//   recipient = 도장을 "받는" 사람 = 원래 sendPouch를 "보낸" 사람
//               (= PointHistory.userId)
//
// [절대 원칙 — Prisma Transaction 강제] GratitudeSeal 생성 + sender/recipient
// 양측 지급(PointPolicy: gratitude_seal_sender=2, gratitude_seal_recipient=5)을
// 반드시 하나의 $transaction으로 처리한다. GratitudeSeal.sourcePouchId의 unique
// 제약이 "sendPouch 1건당 감사 도장 1회"를 DB 레벨에서 강제한다(P2002 → 409).
//
// [검증 순서]
//   1) sourcePouchId에 해당하는 PointHistory(spend/send_pouch) 존재 확인
//   2) 그 PointHistory.sourceId(=wishId)로 Wish 조회, auth.userId가 소원
//      주인인지 확인(본인 소원에 들어온 복주머니만 답례 가능)
//   3) self-send 방어: PointHistory.userId(보낸 사람) === Wish.userId(받은 사람,
//      곧 auth.userId)면 거부 — 자기 소원에 자기가 복을 보낸 경우 답례 불가
//   4) 24시간 이내인지 확인(PointHistory.createdAt 기준)
//   5) GratitudeSeal 생성(unique 제약이 중복 답례를 막음)
//   6) sender(auth.userId) +2복, recipient(원래 보낸 사람) +5복 지급
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import {
  CORS_HEADERS,
  isGratitudeSealExpired,
  toGratitudeSealDto,
} from "../_shared";
import {
  requireUser,
  toWishPublicId,
  unauthorizedResponse,
} from "../../wishes/_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { sourcePouchId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const sourcePouchId = Number(body.sourcePouchId);
  if (!Number.isFinite(sourcePouchId) || sourcePouchId <= 0) {
    return NextResponse.json(
      { success: false, error: "sourcePouchId는 필수입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 1) sourcePouchId → PointHistory(send_pouch) 확인
      const pouchHistory = await tx.pointHistory.findUnique({
        where: { id: sourcePouchId },
      });
      if (
        !pouchHistory ||
        pouchHistory.sourceType !== "send_pouch" ||
        pouchHistory.type !== "spend" ||
        pouchHistory.sourceId == null
      ) {
        throw new Error("POUCH_NOT_FOUND");
      }

      // 2) Wish 조회 + 소유권 확인(본인 소원에 들어온 복주머니만 답례 가능)
      const wish = await tx.wish.findUnique({ where: { id: pouchHistory.sourceId } });
      if (!wish || wish.deletedAt != null) {
        throw new Error("POUCH_NOT_FOUND");
      }
      if (wish.userId !== auth.userId) {
        throw new Error("NOT_POUCH_RECEIVER");
      }

      // 3) self-send 방어 — 자기 소원에 자기가 보낸 복주머니
      const senderOfPouchUserId = pouchHistory.userId;
      if (senderOfPouchUserId === auth.userId) {
        throw new Error("SELF_SEND");
      }

      // 4) 24시간 이내 확인
      if (isGratitudeSealExpired(pouchHistory.createdAt)) {
        throw new Error("EXPIRED");
      }

      // 5) GratitudeSeal 생성 — sourcePouchId unique 제약이 "1건당 1회"를 강제.
      //    이미 존재하면 Prisma가 P2002를 던진다(catch에서 409로 변환).
      const seal = await tx.gratitudeSeal.create({
        data: {
          senderId: auth.userId,
          recipientId: senderOfPouchUserId,
          sourcePouchId: pouchHistory.id,
          wishId: wish.id,
        },
      });

      // 6) 양측 지급 — 금액은 반드시 PointPolicy에서 동적 조회(하드코딩 금지).
      const senderPolicy = await tx.pointPolicy.findUnique({
        where: { sourceType: "gratitude_seal_sender" },
      });
      const recipientPolicy = await tx.pointPolicy.findUnique({
        where: { sourceType: "gratitude_seal_recipient" },
      });

      let senderGranted = 0;
      if (senderPolicy?.isActive && senderPolicy.amount > 0) {
        const outcome = await earnLuckPouch(tx, {
          userId: auth.userId,
          amount: senderPolicy.amount,
          sourceType: "gratitude_seal_sender",
          sourceId: sourcePouchId,
          memo: "감사 도장 답례",
        });
        senderGranted = outcome.grantedAmount;
      }

      let recipientGranted = 0;
      if (recipientPolicy?.isActive && recipientPolicy.amount > 0) {
        const outcome = await earnLuckPouch(tx, {
          userId: senderOfPouchUserId,
          amount: recipientPolicy.amount,
          sourceType: "gratitude_seal_recipient",
          sourceId: sourcePouchId,
          memo: "감사 도장 받음",
        });
        recipientGranted = outcome.grantedAmount;
      }

      // [소원방 개편 · 7] 원래 복주머니를 보낸 사람(recipientId)의 닉네임을
      // 함께 조회한다 — 이 응답을 받는 쪽(auth.userId=도장을 찍은 사람)의
      // 상대는 recipientId다.
      const counterpart = await tx.user.findUnique({
        where: { id: senderOfPouchUserId },
        select: { nickname: true },
      });

      return { seal, wish, senderGranted, recipientGranted, counterpartNickname: counterpart?.nickname ?? "익명" };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          ...toGratitudeSealDto(
            result.seal,
            toWishPublicId(result.wish.id),
            result.recipientGranted,
            result.counterpartNickname
          ),
          senderGrantedAmount: result.senderGranted,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "POUCH_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 복주머니 기록입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "NOT_POUCH_RECEIVER") {
      return NextResponse.json(
        { success: false, error: "본인 소원에 들어온 복주머니에만 답례할 수 있습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    if (message === "SELF_SEND") {
      return NextResponse.json(
        { success: false, error: "자신에게 보낸 복주머니에는 답례할 수 없습니다." },
        { status: 403, headers: CORS_HEADERS }
      );
    }
    if (message === "EXPIRED") {
      return NextResponse.json(
        { success: false, error: "답례 가능 시간(24시간)이 지났습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    // Prisma unique 제약(P2002) — 이미 이 sourcePouchId로 답례한 경우.
    if (
      typeof e === "object" &&
      e !== null &&
      "code" in e &&
      (e as { code?: string }).code === "P2002"
    ) {
      return NextResponse.json(
        { success: false, error: "이미 답례한 복주머니입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/gratitude/seal] 실패:", e);
    return NextResponse.json(
      { success: false, error: "감사 도장 처리에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
