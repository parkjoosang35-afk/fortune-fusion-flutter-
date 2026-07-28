// 공개(비인증) 매칭 수락 API — MatchingRepository.acceptPair() 대응.
//
// [설계결정] 서버는 pendingAccept 상태를 생성하지 않으므로(매칭.like/route.ts 주석 참조)
// 이 엔드포인트는 실질적으로 이미 active인 pair를 멱등적으로 그대로 반환하는 역할만
// 한다(Flutter 화면에 "수락" 버튼이 노출될 일이 없지만, 시그니처 호환을 위해 유지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const EMOJIS = ["🌙", "⭐", "🌿", "☕", "✈️", "🌸", "🍀", "🎈", "🌊", "🔥"];
function pickEmoji(userId: number): string {
  return EMOJIS[userId % EMOJIS.length];
}

function parsePairId(idParam: string): number | null {
  const match = /^pair_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const pairId = parsePairId(id);
  if (pairId === null) {
    return NextResponse.json(
      { success: false, error: "매칭 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number };
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    const pair = await prisma.matchingPair.update({
      where: { id: pairId },
      data: { status: "active" },
      include: { userA: true, userB: true },
    });
    const partner = pair.userAId === userId ? pair.userB : pair.userA;

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `pair_${pair.id}`,
          partnerUserId: String(partner.id),
          partnerNickname: partner.nickname,
          partnerEmoji: pickEmoji(partner.id),
          status: "active",
          matchedAt: pair.matchedAt.toISOString(),
          lastMessage: null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/matching/pairs/[id]/accept] 실패:", e);
    return NextResponse.json(
      { success: false, error: "매칭을 찾을 수 없습니다." },
      { status: 404, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
