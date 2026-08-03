// 공개(비인증) 기능-자산 매핑(FeatureAssetBinding) 조회 API.
// Flutter의 AccessChecker/FeatureAccessProvider가 앱 시작 시 이 목록을 캐시하여
// "화면별 하드코딩 금지" 원칙에 따라 scope별 접근 방식을 정책값으로 판단한다.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const bindings = await prisma.featureAssetBinding.findMany({
      where: { isActive: true },
      orderBy: { scope: "asc" },
    });

    const data = bindings.map((b) => ({
      scope: b.scope,
      featureGroup: b.featureGroup,
      primaryAsset: b.primaryAsset,
      secondaryAssets: b.secondaryAssets ? b.secondaryAssets.split(",").filter(Boolean) : [],
      accessType: b.accessType,
      notes: b.notes,
    }));

    return NextResponse.json(
      { success: true, data },
      { headers: { ...CORS_HEADERS, "Cache-Control": "no-store" } }
    );
  } catch (e) {
    console.error("[GET /api/public/feature-bindings] 실패:", e);
    return NextResponse.json(
      { success: false, error: "기능-자산 매핑 조회 중 오류가 발생했습니다." },
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
