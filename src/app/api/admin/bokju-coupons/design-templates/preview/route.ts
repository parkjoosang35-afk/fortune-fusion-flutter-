// [AI 쿠폰 디자인 표시·숨김 기능 §5 "실시간 미리보기"] GET
// /api/admin/bokju-coupons/design-templates/preview
// 관리자가 11개 체크박스를 켜고 끌 때마다 즉시 호출되는 PNG 미리보기
// 엔드포인트. 아직 템플릿으로 저장하지 않은 상태에서도 미리볼 수 있도록
// visibility를 쿼리스트링으로 직접 받는다(design-preview/route.ts의 기존
// 4종 내장 템플릿 미리보기 패턴을 그대로 따름 — 디바운스된 <img src=...>
// 교체 방식과 호환).
//
// 쿼리 파라미터:
//   templateId: number(선택) — [§9 캠페인 생성 화면 연동] 이미 저장된
//     BokjuCouponDesignTemplate id. 지정하면 그 템플릿의 visibility/배경을
//     그대로 불러와 미리보기를 렌더링한다(visibility/designAssetId 쿼리는 무시).
//   designAssetId: number(선택) — AI 배경 이미지 ID, 없으면 흰 배경
//   visibility: JSON 문자열(선택) — {"logo":true,...} 11개 boolean
//   title, grantAmount, guideText, partnerName: 미리보기용 더미 텍스트(선택)
import { NextRequest, NextResponse } from "next/server";
import { requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { renderCustomTemplatePreview } from "@/lib/bokju-coupon-image-service";
import { normalizeVisibility } from "@/lib/bokju-coupon-visibility";
import { getDesignTemplate } from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const sp = request.nextUrl.searchParams;

  const templateIdRaw = sp.get("templateId");
  const templateId = templateIdRaw && Number.isInteger(Number(templateIdRaw)) ? Number(templateIdRaw) : null;

  let visibility;
  let designAssetId: number | null = null;

  if (templateId != null) {
    // [§9] 저장된 템플릿을 그대로 불러온다 — 캠페인 생성 화면에서 템플릿을
    // 선택했을 때 그 템플릿의 "진짜" 표시 설정으로 미리보기를 보여줘야
    // 하므로, 쿼리로 넘어온 visibility는 무시하고 DB 값을 신뢰한다.
    const tpl = await getDesignTemplate(templateId);
    if (!tpl) {
      return NextResponse.json({ success: false, error: "템플릿을 찾을 수 없습니다." }, { status: 404 });
    }
    visibility = tpl.visibility;
    designAssetId = tpl.designAssetId;
  } else {
    try {
      const raw = sp.get("visibility");
      visibility = normalizeVisibility(raw ? JSON.parse(raw) : {});
    } catch {
      visibility = normalizeVisibility({});
    }
    const designAssetIdRaw = sp.get("designAssetId");
    designAssetId =
      designAssetIdRaw && Number.isInteger(Number(designAssetIdRaw)) ? Number(designAssetIdRaw) : null;
  }

  const title = sp.get("title") || undefined;
  const grantAmountRaw = sp.get("grantAmount");
  const grantAmount = grantAmountRaw && Number.isInteger(Number(grantAmountRaw)) ? Number(grantAmountRaw) : undefined;
  const guideText = sp.get("guideText") || undefined;
  const partnerName = sp.get("partnerName") || undefined;

  try {
    const buf = await renderCustomTemplatePreview({
      visibility,
      designAssetId,
      campaignTitle: title,
      grantAmount,
      guideText,
      partnerOrEventName: partnerName,
    });
    return new NextResponse(new Uint8Array(buf), {
      status: 200,
      headers: { "Content-Type": "image/png", "Cache-Control": "no-store" },
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/design-templates/preview] 실패:", e);
    return NextResponse.json({ success: false, error: "미리보기 생성 중 오류가 발생했습니다." }, { status: 500 });
  }
}
