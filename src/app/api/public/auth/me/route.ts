// 세션 복원용 API — AuthRepository.restoreSession() 대응.
// Authorization: Bearer <token> 헤더의 JWT를 검증해 현재 유저 정보를 반환한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest, toUserDto } from "@/lib/user-auth";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const payload = await authenticateRequest(request);
  if (!payload) {
    return NextResponse.json(
      { success: false, error: "인증이 필요합니다.", code: "UNAUTHORIZED" },
      { status: 401, headers: CORS_HEADERS }
    );
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      include: { grade: true, profile: true },
    });

    if (!user || user.status !== "active") {
      return NextResponse.json(
        { success: false, error: "유효하지 않은 계정입니다.", code: "INVALID_ACCOUNT" },
        { status: 401, headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      { success: true, data: { user: toUserDto(user) } },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/auth/me] 실패:", e);
    return NextResponse.json(
      { success: false, error: "사용자 정보를 불러오지 못했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
