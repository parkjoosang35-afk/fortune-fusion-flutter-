// 공개(비인증) "복주머니로 프리패스 구매" 옵션 목록 조회 API — Flutter
// PassRepository.getPurchaseOptions() 대응.
// [재화 구조 정리] PassPolicy.happyMoneyPrice(복주머니 가격)가 설정된 활성 정책만
// 노출한다 — 마이페이지 프리패스 영역의 "복주머니로 구매" 버튼에서 사용.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest) {
  try {
    const policies = await prisma.passPolicy.findMany({
      where: { isActive: true, deletedAt: null, happyMoneyPrice: { not: null } },
      orderBy: [{ happyMoneyPrice: "asc" }, { id: "asc" }],
    });

    const data = policies.map((p) => ({
      id: p.id,
      name: p.name,
      durationMin: p.durationMin,
      happyMoneyPrice: p.happyMoneyPrice,
      description: p.description,
      uiCopy: p.uiCopy,
    }));

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/pass/purchase-options] 실패:", e);
    return NextResponse.json(
      { success: false, error: "구매 가능한 프리패스 옵션을 불러오지 못했습니다." },
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
