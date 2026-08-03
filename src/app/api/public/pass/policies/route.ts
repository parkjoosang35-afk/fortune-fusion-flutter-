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

    // [프리패스 단순화 - CMS 쿠팡파트너스 배너 연동] §2/§9
    // "CMS 쿠팡파트너스 배너 = 프리패스 광고" 구조에 따라, passType='ad'
    // 정책의 광고 이미지/링크/스크립트는 더 이상 PassPolicy 자체 컬럼이
    // 아니라 Banner(positionCode='open_pass', 활성 + 노출기간 내) 중
    // 가장 우선순위 높은 1건에서 가져온다. 관리자가 CMS에서 이미지를
    // 수정하면 이 API가 즉시 최신값을 반영하므로 앱/웹에 실시간 반영된다.
    const now = new Date();
    const activeAdBanner = await prisma.banner.findFirst({
      where: {
        positionCode: "open_pass",
        isActive: true,
        deletedAt: null,
        OR: [{ startAt: null }, { startAt: { lte: now } }],
        AND: [{ OR: [{ endAt: null }, { endAt: { gte: now } }] }],
      },
      orderBy: [{ sortOrder: "asc" }, { id: "desc" }],
    });

    const data = policies.map((p) => {
      const isAd = p.passType === "ad";
      return {
        id: p.id,
        name: p.name,
        passType: p.passType,
        durationMin: p.durationMin,
        dailyLimit: p.dailyLimit,
        ctaText: p.ctaText,
        // [CMS 배너 연동] ad 타입은 Banner가 있으면 그 값으로 덮어쓰고,
        // 없으면(관리자 미등록) 기존 PassPolicy 컬럼값으로 폴백한다.
        bannerImageUrl: isAd ? (activeAdBanner?.imageUrl ?? p.bannerImageUrl) : p.bannerImageUrl,
        linkUrl: isAd ? (activeAdBanner?.linkUrl ?? p.linkUrl) : p.linkUrl,
        adType: isAd ? (activeAdBanner?.adType ?? "image") : "image",
        adScript: isAd ? (activeAdBanner?.adScript ?? null) : null,
        adWaitSeconds: p.adWaitSeconds,
        bonusPoint: p.bonusPoint,
        // [열림패스/행복머니/복주머니 통합정책] 신규 필드
        description: p.description,
        scope: p.scope.split(",").filter(Boolean),
        happyMoneyPrice: p.happyMoneyPrice,
        adRewardEnabled: p.adRewardEnabled,
        isFeatured: p.isFeatured,
        displayPriority: p.displayPriority,
        uiCopy: p.uiCopy,
      };
    });

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/pass/policies] 실패:", e);
    return NextResponse.json(
      { success: false, error: "프리패스 정책을 불러오지 못했습니다." },
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
