// 공개(비인증) 부적 선물하기 API — Flutter AmuletRepository.gift() 대응.
// user_amulets.status를 gifted로 변경하고 amulet_gifts에 발송 이력을 남긴다.
// [간이 처리] 수신자는 nickname으로 조회(userProfile.nickname 가정 대신 users 테이블에
// nickname 컬럼이 있으면 사용). 존재하지 않으면 404.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseUserAmuletId(raw: unknown): number | null {
  const s = String(raw ?? "");
  const m = s.match(/^ua_(\d+)$/) ?? s.match(/^(\d+)$/);
  if (!m) return null;
  return Number(m[1]);
}

export async function POST(request: NextRequest) {
  let body: {
    userId?: number;
    userAmuletId?: string | number;
    toUserNickname?: string;
    message?: string;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const fromUserId = Number(body.userId ?? 1);
  const userAmuletId = parseUserAmuletId(body.userAmuletId);
  if (userAmuletId == null || !body.toUserNickname) {
    return NextResponse.json(
      { success: false, error: "userAmuletId, toUserNickname이 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    await prisma.$transaction(async (tx) => {
      const userAmulet = await tx.userAmulet.findFirst({
        where: { id: userAmuletId, userId: fromUserId, deletedAt: null },
      });
      if (!userAmulet) throw new Error("NOT_FOUND");
      if (userAmulet.status !== "held") throw new Error("NOT_HELD");

      const toUser = await tx.user.findFirst({
        where: { nickname: body.toUserNickname },
      });
      if (!toUser) throw new Error("RECEIVER_NOT_FOUND");

      await tx.userAmulet.update({
        where: { id: userAmuletId },
        data: { status: "gifted" },
      });

      await tx.amuletGift.create({
        data: {
          fromUserId,
          toUserId: toUser.id,
          userAmuletId,
          message: body.message ?? null,
        },
      });
    });

    return NextResponse.json({ success: true, data: null }, { headers: CORS_HEADERS });
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "보유하지 않은 부적입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "NOT_HELD") {
      return NextResponse.json(
        { success: false, error: "선물할 수 없는 상태의 부적입니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    if (message === "RECEIVER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 닉네임입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/amulets/gift] 실패:", e);
    return NextResponse.json(
      { success: false, error: "부적 선물 처리 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
