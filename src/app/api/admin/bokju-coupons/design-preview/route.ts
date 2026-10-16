// [카카오톡 스타일 쿠폰 디자인 템플릿 4종 — 관리자 미리보기]
// GET /api/admin/bokju-coupons/design-preview?template=CLASSIC|PREMIUM|KAKAO|MINIMAL
//   &title=...&grantAmount=...&guideText=...&validFrom=YYYY-MM-DD&validTo=YYYY-MM-DD
//
// "쿠폰 만들기" 화면(BokjuCampaignCreateForm)에서 아직 캠페인을 저장/발행하기
// 전에, 입력 중인 쿠폰명/지급액/안내문구/유효기간을 그대로 반영한 모바일 쿠폰
// 미리보기 PNG를 4개 디자인 템플릿별로 즉시 확인하기 위한 전용 엔드포인트.
// 실제 발행 이미지(bokju-coupon-image-service.ts의 renderCouponImage)와 완전히
// 동일한 렌더링 함수를 재사용하되, 아직 존재하지 않는 쿠폰이므로 더미
// couponNo/QR 내용으로 대체한다(renderPreviewCouponImage 참고).
import { NextRequest, NextResponse } from "next/server";
import { requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { renderPreviewCouponImage } from "@/lib/bokju-coupon-image-service";
import { BOKJU_COUPON_DESIGN_TEMPLATES } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const sp = request.nextUrl.searchParams;
  const templateRaw = sp.get("template") ?? "CLASSIC";
  const template = BOKJU_COUPON_DESIGN_TEMPLATES.includes(templateRaw as never)
    ? templateRaw
    : "CLASSIC";

  const title = sp.get("title")?.trim() || "신통방통 복주머니 선물";
  const grantAmountNum = Number(sp.get("grantAmount"));
  const grantAmount = Number.isFinite(grantAmountNum) && grantAmountNum > 0 ? grantAmountNum : 100;
  const guideText = sp.get("guideText")?.trim() || null;

  const validFromRaw = sp.get("validFrom");
  const validToRaw = sp.get("validTo");
  const now = new Date();
  const inOneMonth = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const validFrom = validFromRaw && !isNaN(Date.parse(validFromRaw)) ? new Date(validFromRaw) : now;
  const validTo = validToRaw && !isNaN(Date.parse(validToRaw)) ? new Date(validToRaw) : inOneMonth;

  try {
    const buf = await renderPreviewCouponImage({
      designTemplate: template,
      campaignTitle: title,
      grantAmount,
      guideText,
      validFrom,
      validTo,
    });
    return new NextResponse(new Uint8Array(buf), {
      status: 200,
      headers: {
        "Content-Type": "image/png",
        // 입력값이 바뀔 때마다 즉시 새로 그려야 하므로 캐시하지 않는다.
        "Cache-Control": "no-store",
      },
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/design-preview] 실패:", e);
    return NextResponse.json({ success: false, error: "미리보기 생성 중 오류가 발생했습니다." }, { status: 500 });
  }
}
