// 회원 탈퇴 API — AuthRepository.withdrawAccount() 대응.
// users.status를 'withdrawn'으로 전환(소프트 삭제)하고 user_withdrawal_logs에 기록한다.
// dataPurgeScheduledAt은 탈퇴 요청일 + 30일(개인정보 보관 유예기간 관행)로 설정한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const PURGE_GRACE_DAYS = 30;

export async function POST(request: NextRequest) {
  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "인증이 필요합니다.", code: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  let body: { reason?: string };
  try {
    body = await request.json();
  } catch {
    body = {};
  }

  try {
    const existing = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!existing) {
      return NextResponse.json(
        { success: false, error: "유효하지 않은 계정입니다." },
        { status: 401, headers: CORS_HEADERS }
      );
    }
    if (existing.status === "withdrawn") {
      return NextResponse.json(
        { success: false, error: "이미 탈퇴 처리된 계정입니다." },
        { status: 409, headers: CORS_HEADERS }
      );
    }

    const now = new Date();
    const purgeScheduledAt = new Date(now.getTime() + PURGE_GRACE_DAYS * 24 * 60 * 60 * 1000);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: payload.userId },
        data: { status: "withdrawn", withdrawalReason: body.reason ?? null },
      }),
      prisma.userWithdrawalLog.create({
        data: {
          userId: payload.userId,
          reason: body.reason ?? null,
          requestedAt: now,
          dataPurgeScheduledAt: purgeScheduledAt,
        },
      }),
    ]);

    return NextResponse.json({ success: true, data: { withdrawn: true } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[POST /api/public/auth/withdraw] 실패:", e);
    return NextResponse.json(
      { success: false, error: "탈퇴 처리 중 오류가 발생했습니다." },
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
