// 공개(비인증) 열림패스 상품 노출 구성 API — Flutter OpenPassDisplayConfigRepository 대응.
// [사용자 요청] §7/§9 — hero/promo/fallback + usageType별 첨부파일 묶음만 필요할 때
// 상세 API 전체를 부르지 않도록 별도 경량 엔드포인트로 분리.
import { NextRequest, NextResponse } from "next/server";
import { resolveProductDisplayConfig } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const policyId = Number(id);
  if (!Number.isInteger(policyId) || policyId <= 0) {
    return NextResponse.json({ success: false, error: "잘못된 상품 ID입니다." }, { status: 400, headers: CORS_HEADERS });
  }

  try {
    const displayConfig = await resolveProductDisplayConfig(policyId);
    if (!displayConfig) {
      return NextResponse.json({ success: false, error: "존재하지 않는 열림패스 상품입니다." }, { status: 404, headers: CORS_HEADERS });
    }
    return NextResponse.json({ success: true, data: displayConfig }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/open-pass/products/[id]/display-config] 실패:", e);
    return NextResponse.json(
      { success: false, error: "노출 구성을 불러오지 못했습니다." },
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
