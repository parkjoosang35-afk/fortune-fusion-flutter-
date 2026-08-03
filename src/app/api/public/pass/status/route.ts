// 공개(비인증) 사용자 알림패스 현재 상태 조회 API — Flutter PassRepository.getStatus() 대응.
// 현재 유효(만료되지 않은) UserPass가 있으면 반환, 없으면 isActive:false.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const now = new Date();
    const activePass = await prisma.userPass.findFirst({
      where: { userId, expiresAt: { gt: now } },
      orderBy: { expiresAt: "desc" },
      include: { policy: true },
    });

    if (!activePass) {
      return NextResponse.json(
        { success: true, data: { isActive: false } },
        { headers: CORS_HEADERS }
      );
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          isActive: true,
          userPassId: activePass.id,
          policyId: activePass.policyId,
          policyName: activePass.policy.name,
          passType: activePass.policy.passType,
          sourceType: activePass.sourceType,
          activatedAt: activePass.activatedAt.toISOString(),
          expiresAt: activePass.expiresAt.toISOString(),
          remainingSec: Math.max(
            0,
            Math.floor((activePass.expiresAt.getTime() - now.getTime()) / 1000)
          ),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/pass/status] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프리패스 상태를 불러오지 못했습니다." },
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
