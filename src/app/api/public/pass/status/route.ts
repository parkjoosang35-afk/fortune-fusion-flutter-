// 공개(비인증) 사용자 알림패스 현재 상태 조회 API — Flutter PassRepository.getStatus() 대응.
// 현재 유효(만료되지 않은) UserPass가 있으면 반환, 없으면 isActive:false.
//
// [신통방통 기존시스템유지+프리패스 카테고리별 이용횟수 제한] §6/§27 categoryUsage
// 필드를 추가해 "오늘의 운세 1/2, 사주 2/2" 같은 카테고리별 이용현황을 앱이 함께
// 받을 수 있게 한다(activePass가 있을 때만 채워짐 — 없으면 빈 배열). 기존
// 필드(isActive/policyName/remainingSec 등)는 그대로 유지해 하위호환을 보장한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { getCategoryUsageSummary } from "@/lib/open-pass-service";

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

    const categorySummary = await getCategoryUsageSummary(userId);

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
          categoryMaxUsage: categorySummary?.maxUsage ?? null,
          categoryUsage: categorySummary?.usages ?? [],
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
