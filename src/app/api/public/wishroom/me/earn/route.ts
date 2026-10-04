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

        // [버그수정 — 전수감사] m_visit/m_cheer/m_msg는 그동안 실제 행동(방문/응원/댓글)을
        // 전혀 검증하지 않고 클릭만으로 즉시 지급되고 있었다. devo10이 auto=true로 보호되는
        // 것과 동일한 수준의 보호를 걸기 위해, 각 미션의 실제 기록 테이블을 오늘(KST) 기준
        // 으로 조회해 조건을 충족했는지 확인한다. 미충족 시 MISSION_INCOMPLETE로 거부.
        if (src.id === "m_visit") {
          const visited = await tx.wishRoomVisit.findMany({
            where: { userId: auth.userId, dateKey: today },
            select: { roomId: true },
            distinct: ["roomId"],
          });
          if (visited.length < 3) {
            throw new WishRoomError(400, "MISSION_INCOMPLETE", `다른 소원방을 ${3 - visited.length}곳 더 둘러봐야 해요`);
          }
        } else if (src.id === "m_cheer") {
          const supported = await tx.wishRoomSupport.findMany({
            where: { userId: auth.userId, dateKey: today },
            select: { roomId: true },
            distinct: ["roomId"],
          });
          if (supported.length < 3) {
            throw new WishRoomError(400, "MISSION_INCOMPLETE", `응원을 ${3 - supported.length}번 더 보내야 해요`);
          }
        } else if (src.id === "m_msg") {
          const dayStart = new Date(Date.parse(today + "T00:00:00+09:00"));
          const dayEnd = new Date(dayStart.getTime() + 86400000);
          const commented = await tx.wishRoomComment.count({
            where: { userId: auth.userId, createdAt: { gte: dayStart, lt: dayEnd }, deletedAt: null },
          });
          if (commented < 1) {
            throw new WishRoomError(400, "MISSION_INCOMPLETE", "응원 메시지를 먼저 남겨주세요");
          }
        }

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
