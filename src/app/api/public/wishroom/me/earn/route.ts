// 수동 획득처(광고 시청/출석/미션) 복주머니 적립 — Flutter WrRepository.earn() 대응. [SERVER] 일일 한도.
// [원본] app/api.js 보조 · POST /me/earn { source }. EARN[].auto=true 항목(자동 지급)은
// 이 라우트로 직접 호출할 수 없다(400 AUTO) — 서버 내부 트리거로만 지급되어야 함.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { kstDate, WishRoomError, WR } from "@/lib/wishroom-engine";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { requireUser, unauthorizedResponse, wishroomOptionsResponse, CORS_HEADERS, toErrorResponse, buildMeView } from "../../_shared";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: { source?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, error: "요청 본문이 올바르지 않습니다.", code: "BAD_REQUEST" }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const data = await prisma.$transaction(async (tx) => {
      const src = WR.EARN.find((e) => e.id === body.source);
      if (!src) throw new WishRoomError(404, "NOT_FOUND", "알 수 없는 획득처");
      if (src.auto) throw new WishRoomError(400, "AUTO", "자동 지급 항목이에요");

      const today = kstDate();
      const count = await tx.wishRoomEarnLog.count({ where: { userId: auth.userId, source: src.id, dateKey: today } });
      if (count >= src.limit) throw new WishRoomError(429, "EARN_LIMIT", "오늘은 모두 받았어요");

      await earnLuckPouch(tx, {
        userId: auth.userId,
        amount: src.amount,
        sourceType: `wishroom_earn_${src.id}`,
        memo: `${src.label} · ${src.sub}`,
      });
      await tx.wishRoomEarnLog.create({ data: { userId: auth.userId, source: src.id, amount: src.amount, dateKey: today } });

      const me = await buildMeView(tx, auth.userId);
      return { amount: src.amount, me };
    });

    return NextResponse.json({ success: true, data }, { status: 201, headers: CORS_HEADERS });
  } catch (e) {
    return toErrorResponse(e);
  }
}

export async function OPTIONS() {
  return wishroomOptionsResponse();
}
