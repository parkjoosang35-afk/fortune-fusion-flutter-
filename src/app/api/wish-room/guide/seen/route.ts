// 공개(비인증) 가이드 확인 처리 API — Flutter WishRoomRepository.markGuideSeen() 대응.
//
// [설계] "최초 진입 가이드를 봤는지" 여부는 기기 로컬(SharedPreferences)이 아니라
// 서버(WishRoomProfile.hasSeenGuide)가 단일 진실 원천으로 관리한다 — 이래야
// 같은 회원이 다른 기기로 접속해도 가이드가 중복 노출되지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getOrCreateWishRoomProfile, CORS_HEADERS, corsOptionsResponse } from "@/lib/wish-room-service";

export const dynamic = "force-dynamic";

interface SeenBody {
  userId?: number;
}

export async function POST(request: NextRequest) {
  let body: SeenBody;
  try {
    body = await request.json();
  } catch {
    body = {};
  }
  const userId = Number(body.userId ?? 1);

  try {
    await prisma.$transaction(async (tx) => {
      await getOrCreateWishRoomProfile(tx, userId);
      await tx.wishRoomProfile.update({ where: { userId }, data: { hasSeenGuide: true } });
    });
    return NextResponse.json({ success: true, data: { hasSeenGuide: true } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/wish-room/guide/seen] 실패:", e);
    return NextResponse.json({ success: false, error: "처리에 실패했습니다." }, { status: 500, headers: CORS_HEADERS });
  }
}

export async function OPTIONS() {
  return corsOptionsResponse("POST");
}
