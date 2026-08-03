// 공개(비인증) 열림패스 상품 목록 API — Flutter OpenPassProductRepository.getProducts() 대응.
// [사용자 요청: 열림패스 관리자 첨부파일/광고소스 연동] §7/§9-1
// 기존 /api/public/pass/policies(레거시, 배너/링크만)와 달리, 관리자가 등록한
// 대표(hero)/광고유도(promo) 첨부파일과 "이 상품에 시청 가능한 광고소스가 있는지"까지
// 함께 내려준다. 앱은 이 응답만으로 카드 UI(배너 이미지, 광고 버튼 노출 여부,
// 행복머니 구매 버튼 노출 여부)를 그릴 수 있어야 한다(§10 UI 동작).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { serializeAttachment } from "@/lib/open-pass-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(_request: NextRequest) {
  try {
    const policies = await prisma.passPolicy.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ displayPriority: "asc" }, { id: "asc" }],
    });

    const data = await Promise.all(
      policies.map(async (p) => {
        const [heroAttachment, promoAttachment, activeAdSourceCount] = await Promise.all([
          p.heroAttachmentId ? prisma.openPassAttachment.findUnique({ where: { id: p.heroAttachmentId } }) : null,
          p.promoAttachmentId ? prisma.openPassAttachment.findUnique({ where: { id: p.promoAttachmentId } }) : null,
          p.adRewardEnabled
            ? prisma.openPassProductAdSource.count({
                where: { passPolicyId: p.id, isActive: true, adSource: { isActive: true, deletedAt: null } },
              })
            : Promise.resolve(0),
        ]);

        return {
          id: p.id,
          name: p.name,
          passType: p.passType,
          durationMin: p.durationMin,
          dailyLimit: p.dailyLimit,
          description: p.description,
          scope: p.scope.split(",").filter(Boolean),
          happyMoneyPrice: p.happyMoneyPrice,
          // 광고 버튼은 adRewardEnabled && 실제로 활성 광고소스가 1개 이상 연결된 경우에만 노출해야 한다
          // (§15 "앱이 광고소스 존재 여부를 임의 판단하면 안 됨" — 서버가 직접 판단해 내려준다).
          adRewardEnabled: p.adRewardEnabled && activeAdSourceCount > 0,
          isFeatured: p.isFeatured,
          displayPriority: p.displayPriority,
          uiCopy: p.uiCopy,
          heroAttachment: serializeAttachment(heroAttachment),
          promoAttachment: serializeAttachment(promoAttachment),
        };
      })
    );

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/open-pass/products] 실패:", e);
    return NextResponse.json(
      { success: false, error: "열림패스 상품을 불러오지 못했습니다." },
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
