// [신규 제안 — 사용자 승인됨] 감사 도장을 찍을 수 있는 대상 목록 조회 API
// `GET /gratitude/sealable`.
//
// [배경] bokjumeoni-plan 03-dev-spec.html의 API 표에는 `POST /gratitude/seal`
// (실행)과 `GET /gratitude/received`(받은 도장 조회)만 있고, "어떤 sourcePouchId에
// 도장을 찍을 수 있는지" 알려주는 조회 API가 없다. 소원 상세/응원 목록 화면에
// 발신자별 sendPouch 목록이 아직 노출되지 않으므로, 이 API 없이는 클라이언트가
// seal 대상을 알아낼 방법이 전혀 없다 — 그래서 신설한다(사용자 승인, "f" 확인).
//
// 로그인 사용자의 소원(Wish.userId = auth.userId)에 들어온 sendPouch 중:
//   - 24시간 이내(PointHistory.createdAt 기준)
//   - 아직 GratitudeSeal이 생성되지 않음(sourcePouchId 미사용)
//   - self-send가 아님(PointHistory.userId !== auth.userId)
// 인 것만 반환한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, GRATITUDE_SEAL_WINDOW_HOURS, toSealableCandidateDto } from "../_shared";
import { requireUser, toWishPublicId, unauthorizedResponse } from "../../wishes/_shared";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  try {
    const windowStart = new Date(Date.now() - GRATITUDE_SEAL_WINDOW_HOURS * 60 * 60 * 1000);

    // 1) 내가 주인인 소원 id 목록
    const myWishes = await prisma.wish.findMany({
      where: { userId: auth.userId, deletedAt: null },
      select: { id: true },
    });
    const myWishIds = myWishes.map((w) => w.id);
    if (myWishIds.length === 0) {
      return NextResponse.json({ success: true, data: [] }, { headers: CORS_HEADERS });
    }

    // 2) 그 소원들에 24시간 이내 들어온 sendPouch(PointHistory) 목록
    //    self-send 방어: userId(보낸 사람) !== auth.userId(내 소원 주인 = 나)
    const pouchHistories = await prisma.pointHistory.findMany({
      where: {
        type: "spend",
        sourceType: "send_pouch",
        sourceId: { in: myWishIds },
        userId: { not: auth.userId },
        createdAt: { gte: windowStart },
      },
      orderBy: { createdAt: "desc" },
    });
    if (pouchHistories.length === 0) {
      return NextResponse.json({ success: true, data: [] }, { headers: CORS_HEADERS });
    }

    // 3) 이미 답례한 sourcePouchId 제외
    const existingSeals = await prisma.gratitudeSeal.findMany({
      where: { sourcePouchId: { in: pouchHistories.map((h) => h.id) } },
      select: { sourcePouchId: true },
    });
    const sealedSet = new Set(existingSeals.map((s) => s.sourcePouchId));

    const wishIdToPublicId = new Map(myWishIds.map((id) => [id, toWishPublicId(id)]));

    // [소원방 개편 · 7] 발신자 닉네임 조회 — 새 필드/스키마 없이 이미
    // PointHistory.userId(=보낸 사람)에 존재하는 값을 User.nickname으로
    // 한 번에 조회해 맵으로 구성한다(N+1 방지).
    const senderIds = [...new Set(pouchHistories.map((h) => h.userId))];
    const senders = await prisma.user.findMany({
      where: { id: { in: senderIds } },
      select: { id: true, nickname: true },
    });
    const senderNicknameMap = new Map(senders.map((u) => [u.id, u.nickname]));

    const data = pouchHistories
      .filter((h) => !sealedSet.has(h.id))
      .map((h) =>
        toSealableCandidateDto({
          sourcePouchId: h.id,
          wishId: wishIdToPublicId.get(h.sourceId as number) ?? toWishPublicId(h.sourceId as number),
          amount: Math.abs(h.amount),
          pouchCreatedAt: h.createdAt,
          senderNickname: senderNicknameMap.get(h.userId) ?? "익명",
        })
      );

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/gratitude/sealable] 실패:", e);
    return NextResponse.json(
      { success: false, error: "답례 가능한 복주머니 목록을 불러오지 못했습니다." },
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
