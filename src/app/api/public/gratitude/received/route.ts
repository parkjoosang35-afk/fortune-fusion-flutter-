// 내가 받은 감사 도장 목록 API — bokjumeoni-plan §03 SERVER API
// `GET /gratitude/received` 대응(in-app 알림 리스트용, 푸시 없음).
//
// 로그인 사용자가 recipient(=원래 sendPouch를 보낸 사람)로 받은 GratitudeSeal
// 전체를 최신순으로 반환한다. grantedAmount는 그 감사 도장으로 실제 지급된
// 금액을 PointHistory(sourceType='gratitude_seal_recipient', sourceId=
// sourcePouchId)에서 조회해 채운다(일일 상한 클리핑으로 정책 금액보다 적게
// 지급됐을 가능성을 반영, 이력 원장과 항상 일치시키기 위함).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, toGratitudeSealDto } from "../_shared";
import { requireUser, toWishPublicId, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const seals = await prisma.gratitudeSeal.findMany({
      where: { recipientId: auth.userId },
      orderBy: { createdAt: "desc" },
      include: { sender: { select: { nickname: true } } },
    });

    if (seals.length === 0) {
      return NextResponse.json({ success: true, data: [] }, { headers: CORS_HEADERS });
    }

    // 각 도장의 실제 지급 금액을 PointHistory에서 조회(sourceId=sourcePouchId).
    const grantHistories = await prisma.pointHistory.findMany({
      where: {
        userId: auth.userId,
        sourceType: "gratitude_seal_recipient",
        sourceId: { in: seals.map((s) => s.sourcePouchId) },
      },
      select: { sourceId: true, amount: true },
    });
    const grantedBySourceId = new Map<number, number>();
    for (const h of grantHistories) {
      if (h.sourceId != null) grantedBySourceId.set(h.sourceId, h.amount);
    }

    // [소원방 개편 · 7] 여기서 나(recipient)의 상대는 도장을 찍어준
    // sender다 — sender.nickname을 counterpartNickname으로 노출한다.
    const data = seals.map((seal) =>
      toGratitudeSealDto(
        seal,
        toWishPublicId(seal.wishId),
        grantedBySourceId.get(seal.sourcePouchId) ?? 0,
        seal.sender?.nickname ?? "익명"
      )
    );

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/gratitude/received] 실패:", e);
    return NextResponse.json(
      { success: false, error: "받은 감사 도장 목록을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
