// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 3] POST
// /api/admin/bokju-coupons/campaigns/:id/design/preview
//
// 에디터에서 "지금 이 레이아웃이 어떻게 보이는가"를 서버 렌더(sharp)로
// 확인하기 위한 엔드포인트. 캠페인의 실제 title/grantAmount/guideText/
// validFrom/validTo는 그대로 쓰되, 쿠폰번호·QR은 [02e §0-G 필수2]에 따라
// **샘플 토큰**으로 렌더한다(studio-api.ts의 previewDesign() 참고 — 이
// 함수는 BokjuCoupon 테이블을 전혀 읽거나 쓰지 않아 샘플 값이 실제 쿠폰과
// 섞일 경로가 구조적으로 없다).
//
// 응답 헤더에 X-Preview-Sample: true 를 추가해 "이 이미지는 샘플"임을
// 코드 레벨에서도 구분 가능하게 한다(에디터가 화면에 안내 배지를 띄울 때
// 이 헤더를 참고할 수 있다 — 필수는 아니지만 안전망).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { jsonError, requireAdminOrResponse, isAdminActor, resolvePublicOrigin } from "@/lib/page-config-helpers";
import { previewDesign } from "@/lib/bokju-coupon-design/studio-api";

export const dynamic = "force-dynamic";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

    const body = await request.json().catch(() => ({}));
    const registerBaseUrl = resolvePublicOrigin(request);

    const { buffer } = await previewDesign({
      layout: body.layout,
      campaignTitle: campaign.title,
      grantAmount: campaign.grantAmount,
      guideText: campaign.guideText,
      validFrom: campaign.validFrom,
      validTo: campaign.validTo,
      registerBaseUrl,
      partnerName: typeof body.partnerName === "string" ? body.partnerName : undefined,
    });

    return new NextResponse(new Uint8Array(buffer), {
      status: 200,
      headers: {
        "Content-Type": "image/png",
        "Cache-Control": "no-store",
        // [§0-G 필수2] 이 이미지가 샘플 토큰으로 렌더됐음을 헤더로도 명시.
        "X-Preview-Sample": "true",
      },
    });
  } catch (e) {
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/design/preview] 실패:", e);
    return jsonError("미리보기 생성 중 오류가 발생했습니다.", 500);
  }
}
