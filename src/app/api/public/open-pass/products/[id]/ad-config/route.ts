// 공개(비인증) 열림패스 상품 광고 설정 API — Flutter OpenPassAdConfigRepository/AdSourceResolver 대응.
// [사용자 요청] §7/§9 — 앱이 광고 시청 버튼을 눌렀을 때 "지금 어떤 adUnitId로 요청해야
// 하는지"를 결정하기 위한 엔드포인트. platform/userId를 넘기면 서버가 우선순위(priority) +
// 자격(쿨다운/일일제한/활성상태)까지 판단해 정렬된 배열로 내려주므로, 앱은 배열의 첫 번째
// eligible=true 항목만 사용하면 된다(§15 "앱이 임의로 우선순위를 정하면 안 됨").
import { NextRequest, NextResponse } from "next/server";
import { resolveProductAdConfig } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const policyId = Number(id);
  if (!Number.isInteger(policyId) || policyId <= 0) {
    return NextResponse.json({ success: false, error: "잘못된 상품 ID입니다." }, { status: 400, headers: CORS_HEADERS });
  }

  const { searchParams } = new URL(request.url);
  const platform = searchParams.get("platform") ?? "all";
  const userIdParam = searchParams.get("userId");
  const userId = userIdParam ? Number(userIdParam) : undefined;

  try {
    const adSources = await resolveProductAdConfig(policyId, platform, userId);
    return NextResponse.json(
      {
        success: true,
        data: {
          adSources,
          // 앱이 바로 쓸 수 있는 "지금 시청 가능한 대표 광고소스" — 없으면 null(=fallback/구매 CTA로 유도).
          nextEligible: adSources.find((a) => a.eligible !== false) ?? null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/open-pass/products/[id]/ad-config] 실패:", e);
    return NextResponse.json(
      { success: false, error: "광고 설정을 불러오지 못했습니다." },
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
