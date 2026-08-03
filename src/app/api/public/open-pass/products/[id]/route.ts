// 공개(비인증) 열림패스 상품 상세 API — Flutter OpenPassProductRepository.getProductDetail() 대응.
// [사용자 요청] §7/§9-1 상품 상세: 기본정보 + display-config + ad-config를 한번에 내려줘
// 상세 팝업(§10 UI 동작: 배너/기간/광고버튼/구매버튼/설명/첨부 상세영역)을 한 번의 호출로 그릴 수 있게 한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { resolveProductDisplayConfig, resolveProductAdConfig } from "@/lib/open-pass-service";

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
    const policy = await prisma.passPolicy.findFirst({ where: { id: policyId, deletedAt: null } });
    if (!policy) {
      return NextResponse.json({ success: false, error: "존재하지 않는 열림패스 상품입니다." }, { status: 404, headers: CORS_HEADERS });
    }

    const [displayConfig, adConfig] = await Promise.all([
      resolveProductDisplayConfig(policyId),
      resolveProductAdConfig(policyId, platform, userId),
    ]);

    return NextResponse.json(
      {
        success: true,
        data: {
          id: policy.id,
          name: policy.name,
          passType: policy.passType,
          durationMin: policy.durationMin,
          dailyLimit: policy.dailyLimit,
          description: policy.description,
          scope: policy.scope.split(",").filter(Boolean),
          happyMoneyPrice: policy.happyMoneyPrice,
          adRewardEnabled: policy.adRewardEnabled && adConfig.some((a) => a.eligible !== false),
          isFeatured: policy.isFeatured,
          uiCopy: policy.uiCopy,
          displayConfig,
          adSources: adConfig,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/open-pass/products/[id]] 실패:", e);
    return NextResponse.json(
      { success: false, error: "열림패스 상품 상세를 불러오지 못했습니다." },
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
