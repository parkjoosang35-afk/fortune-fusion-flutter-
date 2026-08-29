// [Phase C - 웰컴 리워드 팝업 1회성 노출] WelcomeRewardModal(Flutter)의 CTA
// ("복주머니 받기") 탭 시 호출되는 API. users.welcome_gift_claimed를 true로
// 전환해, 이후 세션 복원(/me)·재로그인 시 팝업이 다시 뜨지 않도록 한다.
// 이미 true인 상태로 재호출돼도 멱등(idempotent)하게 동작한다(에러 아님).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest, toUserDto } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "인증이 필요합니다.", code: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  try {
    const updated = await prisma.user.update({
      where: { id: payload.userId },
      data: { welcomeGiftClaimed: true },
      include: { grade: true, profile: true },
    });

    return NextResponse.json(
      { success: true, data: { user: toUserDto(updated) } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/auth/welcome-gift/claim] 실패:", e);
    return NextResponse.json(
      { success: false, error: "처리 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
