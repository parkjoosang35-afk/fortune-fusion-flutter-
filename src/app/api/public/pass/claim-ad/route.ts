// 공개(비인증) 광고 시청 프리패스 발급 API — Flutter PassRepository.claimAd() 대응.
// 광고 시청 완료 콜백 시 호출: passType="ad" 정책을 조회해 UserPass를 발급한다.
// [재화 구조 정리] 프리패스는 순수 시간제 이용권이므로 지급 시 상시 복주머니 적립을
// 붙이지 않는다(과거 policy.bonusPoint 자동 지급 블록 제거).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; policyId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);

  try {
    const policy = body.policyId
      ? await prisma.passPolicy.findFirst({
          where: { id: Number(body.policyId), passType: "ad", isActive: true, deletedAt: null },
        })
      : await prisma.passPolicy.findFirst({
          where: { passType: "ad", isActive: true, deletedAt: null },
          orderBy: { id: "asc" },
        });

    if (!policy) {
      return NextResponse.json(
        { success: false, error: "활성화된 광고 프리패스 정책이 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    // [프리패스 단순화 - 자동지급 안전장치] §4/§9
    // "쿠팡 방문 후 대기시간이 지나면 버튼을 다시 누를 필요 없이 자동
    // 지급"하는 흐름에서는 앱 라이프사이클 이벤트가 중복 발생(예: 빠른
    // 화면 전환/재진입)해도 claim-ad가 여러 번 호출될 수 있다. 이미
    // 유효한(만료되지 않은) 프리패스가 있으면 새로 발급하지 않고 기존
    // 발급 건을 그대로 반환해 중복 지급/시간 손해를 방지한다.
    const now0 = new Date();
    const existingActive = await prisma.userPass.findFirst({
      where: { userId, expiresAt: { gt: now0 } },
      orderBy: { expiresAt: "desc" },
    });
    if (existingActive) {
      return NextResponse.json(
        {
          success: true,
          data: {
            userPassId: existingActive.id,
            policyId: existingActive.policyId,
            policyName: policy.name,
            expiresAt: existingActive.expiresAt.toISOString(),
            idempotent: true,
          },
        },
        { headers: CORS_HEADERS }
      );
    }

    // 1일 발급 한도 체크(dailyLimit이 있는 경우)
    if (policy.dailyLimit != null) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayCount = await prisma.userPass.count({
        where: { userId, policyId: policy.id, createdAt: { gte: todayStart } },
      });
      if (todayCount >= policy.dailyLimit) {
        return NextResponse.json(
          { success: false, error: "오늘의 광고 프리패스 발급 한도를 초과했습니다." },
          { status: 429, headers: CORS_HEADERS }
        );
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const now = new Date();
      const expiresAt = new Date(now.getTime() + policy.durationMin * 60 * 1000);

      const userPass = await tx.userPass.create({
        data: {
          userId,
          policyId: policy.id,
          activatedAt: now,
          expiresAt,
          sourceType: "ad",
        },
      });

      await tx.operationLog.create({
        data: {
          actorType: "user",
          actorId: userId,
          action: "claim_ad_pass",
          targetType: "user_pass",
          targetId: userPass.id,
          before: null,
          after: JSON.stringify({ policyId: policy.id, expiresAt: expiresAt.toISOString() }),
        },
      });

      return { userPass, expiresAt };
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          userPassId: result.userPass.id,
          policyId: policy.id,
          policyName: policy.name,
          expiresAt: result.expiresAt.toISOString(),
          idempotent: false,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/pass/claim-ad] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 프리패스 발급 중 오류가 발생했습니다." },
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
