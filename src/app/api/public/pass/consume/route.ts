// 공개(비인증) 알림패스 소진(게이트 체크) API — Flutter PassRepository.consume() 대응.
// 시간제 콘텐츠(운세 상세 등) 열람 직전 호출: 현재 유효한 UserPass가 있는지 검증하고,
// 유효하면 열람 로그(operation_logs)를 남긴 뒤 통과시킨다. 알림패스 자체는 시간 기반이라
// 열람 1회당 잔여시간을 차감하지 않고, "이 열람이 패스로 커버되었다"는 이력만 남긴다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; contentType?: string; contentId?: number | string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const contentType = body.contentType ?? "unknown";

  try {
    const now = new Date();
    const activePass = await prisma.userPass.findFirst({
      where: { userId, expiresAt: { gt: now } },
      orderBy: { expiresAt: "desc" },
      include: { policy: true },
    });

    if (!activePass) {
      return NextResponse.json(
        {
          success: false,
          error: "유효한 알림패스가 없습니다. 광고 시청, 파트너 방문 또는 구독으로 알림패스를 받아보세요.",
        },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    await prisma.operationLog.create({
      data: {
        actorType: "user",
        actorId: userId,
        action: "consume_pass",
        targetType: "user_pass",
        targetId: activePass.id,
        before: null,
        after: JSON.stringify({ contentType, contentId: body.contentId ?? null }),
      },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: activePass.id,
          policyId: activePass.policyId,
          policyName: activePass.policy.name,
          remainingSec: Math.max(
            0,
            Math.floor((activePass.expiresAt.getTime() - now.getTime()) / 1000)
          ),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/consume] 실패:", e);
    return NextResponse.json(
      { success: false, error: "알림패스 검증 중 오류가 발생했습니다." },
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
