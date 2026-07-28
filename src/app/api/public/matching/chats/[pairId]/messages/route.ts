// 공개(비인증) 매칭 채팅 메시지 조회/전송 API — MatchingRepository.getMessages()/
// sendMessage() 대응. 06§11.2 스펙상 WebSocket이나, 인프라 도입 전까지 REST 폴링으로
// 간소화(Mock 단계와 동일 원칙 유지).
//
// chat_rooms(type="matching", relatedPairId)를 pairId 기준으로 find-or-create한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parsePairId(idParam: string): number | null {
  const match = /^pair_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

async function findOrCreateRoom(pairId: number) {
  const existing = await prisma.chatRoom.findFirst({
    where: { relatedPairId: pairId, type: "matching" },
  });
  if (existing) return existing;
  return prisma.chatRoom.create({
    data: { type: "matching", relatedPairId: pairId, status: "active" },
  });
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ pairId: string }> }
) {
  const { pairId: pairIdParam } = await params;
  const pairId = parsePairId(pairIdParam);
  if (pairId === null) {
    return NextResponse.json(
      { success: false, error: "매칭 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  try {
    const room = await prisma.chatRoom.findFirst({
      where: { relatedPairId: pairId, type: "matching" },
    });
    if (!room) {
      return NextResponse.json({ success: true, data: [] }, { headers: CORS_HEADERS });
    }
    const messages = await prisma.chatMessage.findMany({
      where: { roomId: room.id, status: "active" },
      orderBy: { createdAt: "asc" },
    });
    const data = messages.map((m) => ({
      id: `msg_${m.id}`,
      pairId: `pair_${pairId}`,
      isMine: m.senderId === userId,
      content: m.content,
      sentAt: m.createdAt.toISOString(),
    }));
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/matching/chats/[pairId]/messages] 실패:", e);
    return NextResponse.json(
      { success: false, error: "메시지를 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ pairId: string }> }
) {
  const { pairId: pairIdParam } = await params;
  const pairId = parsePairId(pairIdParam);
  if (pairId === null) {
    return NextResponse.json(
      { success: false, error: "매칭 id가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  let body: { userId?: number; content?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const userId = Number(body.userId ?? 1);
  const content = (body.content ?? "").trim();
  if (!content) {
    return NextResponse.json(
      { success: false, error: "메시지를 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const room = await findOrCreateRoom(pairId);
    const message = await prisma.chatMessage.create({
      data: { roomId: room.id, senderId: userId, content, messageType: "text" },
    });
    return NextResponse.json(
      {
        success: true,
        data: {
          id: `msg_${message.id}`,
          pairId: `pair_${pairId}`,
          isMine: true,
          content: message.content,
          sentAt: message.createdAt.toISOString(),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/matching/chats/[pairId]/messages] 실패:", e);
    return NextResponse.json(
      { success: false, error: "메시지 전송에 실패했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
