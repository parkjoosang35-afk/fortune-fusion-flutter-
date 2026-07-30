// 공개(비인증) 알림패스 정책 목록 조회 API — Flutter PassRepository.getPolicies() 대응.
// 홈 화면 알림패스 섹션에 노출할 CTA 카드 목록(광고/파트너/구독/이벤트) 반환.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest) {
  try {
    const policies = await prisma.passPolicy.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ passType: "asc" }, { id: "asc" }],
    });

    const data = policies.map((p) => ({
      id: p.id,
      name: p.name,
      passType: p.passType,
      durationMin: p.durationMin,
      dailyLimit: p.dailyLimit,
      ctaText: p.ctaText,
      bannerImageUrl: p.bannerImageUrl,
      linkUrl: p.linkUrl,
      bonusPoint: p.bonusPoint,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/pass/policies] 실패:", e);
    return NextResponse.json(
      { success: false, error: "알림패스 정책을 불러오지 못했습니다." },
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
