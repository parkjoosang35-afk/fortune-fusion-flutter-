// 공개(비인증) 매칭 성사 목록 조회 API — MatchingRepository.getPairs() 대응.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const EMOJIS = ["🌙", "⭐", "🌿", "☕", "✈️", "🌸", "🍀", "🎈", "🌊", "🔥"];
function pickEmoji(userId: number): string {
  return EMOJIS[userId % EMOJIS.length];
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const pairs = await prisma.matchingPair.findMany({
      where: {
        OR: [{ userAId: userId }, { userBId: userId }],
        deletedAt: null,
      },
      include: {
        userA: true,
        userB: true,
        chatRooms: {
          include: {
            messages: {
              orderBy: { createdAt: "desc" },
              take: 1,
            },
          },
        },
      },
      orderBy: { matchedAt: "desc" },
    });

    const data = pairs.map((p) => {
      const partner = p.userAId === userId ? p.userB : p.userA;
      const room = p.chatRooms[0];
      const lastMessage = room?.messages[0]?.content ?? null;
      return {
        id: `pair_${p.id}`,
        partnerUserId: String(partner.id),
        partnerNickname: partner.nickname,
        partnerEmoji: pickEmoji(partner.id),
        // pendingAccept는 서버에서 절대 반환하지 않음(설계결정 - like API 주석 참조)
        status: p.status === "unmatched" ? "unmatched" : "active",
        matchedAt: p.matchedAt.toISOString(),
        lastMessage,
      };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/matching/pairs] 실패:", e);
    return NextResponse.json(
      { success: false, error: "매칭 목록을 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
