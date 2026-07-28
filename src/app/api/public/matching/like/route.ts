// 공개(비인증) 매칭 좋아요(관심표시) API — MatchingRepository.like() 대응.
//
// [설계결정 - pendingAccept 상태 표현] Flutter MatchingPairStatus에는 Mock 전용
// pendingAccept 개념이 있었으나, 04A 실제 DB matching_pairs.status는 active/unmatched
// 2종뿐이다. 이번 실API 연동부터는 "수락 대기" 단계를 별도로 두지 않고, 상호 좋아요가
// 확인되는 즉시 matching_pairs를 status="active"로 생성한다(자연스러운 앱 UX: 서로
// 좋아요를 누르면 바로 매�칭). 서버는 pendingAccept를 절대 반환하지 않으므로 화면의
// "수락" 버튼은 자연히 노출되지 않고, endPair(매칭 종료)만 실질적으로 쓰인다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; targetUserId?: string | number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const targetUserId = Number(body.targetUserId);
  if (!Number.isInteger(targetUserId) || targetUserId <= 0) {
    return NextResponse.json(
      { success: false, error: "targetUserId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (targetUserId === userId) {
    return NextResponse.json(
      { success: false, error: "자기 자신에게는 좋아요를 보낼 수 없습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const matched = await prisma.$transaction(async (tx) => {
      // 이미 좋아요를 보냈다면 그대로 유지(중복 방지, upsert)
      await tx.matchingLike.upsert({
        where: { fromUserId_toUserId: { fromUserId: userId, toUserId: targetUserId } },
        update: { status: "active" },
        create: { fromUserId: userId, toUserId: targetUserId, status: "active" },
      });

      // 상대방도 나를 좋아요했는지 확인(상호 확인)
      const reverse = await tx.matchingLike.findUnique({
        where: { fromUserId_toUserId: { fromUserId: targetUserId, toUserId: userId } },
      });
      if (!reverse || reverse.status !== "active") {
        return false;
      }

      // 이미 매칭 pair가 존재하면 중복 생성하지 않음
      const userAId = Math.min(userId, targetUserId);
      const userBId = Math.max(userId, targetUserId);
      const existingPair = await tx.matchingPair.findUnique({
        where: { userAId_userBId: { userAId, userBId } },
      });
      if (existingPair) {
        if (existingPair.status !== "active") {
          await tx.matchingPair.update({
            where: { id: existingPair.id },
            data: { status: "active", matchedAt: new Date() },
          });
        }
        return true;
      }

      await tx.matchingPair.create({
        data: { userAId, userBId, status: "active" },
      });
      return true;
    });

    return NextResponse.json({ success: true, data: matched }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/matching/like] 실패:", e);
    return NextResponse.json(
      { success: false, error: "좋아요 처리 중 오류가 발생했습니다." },
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
