// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/allocations/:id/recall
// 미등록 쿠폰 회수. 업체 보고 수량(reportedQty)이 시스템상 미등록 수량보다 많으면
// "고객이 받았지만 아직 등록 안 했을 수 있음" 경고와 함께 RECALL_CONFIRM_REQUIRED를
// 반환한다 — confirm:true로 재요청해야 강제 진행(서비스 레이어가 판단, 여기선 전달만).
import { NextResponse } from "next/server";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor, CORS_HEADERS } from "@/lib/page-config-helpers";
import { recallUnregistered, BokjuCouponError } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) return jsonError("allocationId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const confirm = body?.confirm === true;
    const result = await recallUnregistered(allocationId, confirm);
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) {
      // RECALL_CONFIRM_REQUIRED는 "에러"가 아니라 "확인 필요" 안내이므로 details를 함께 내려
      // 관리자 화면이 확인 다이얼로그를 띄울 수 있게 한다(success:false지만 409로 구분).
      return NextResponse.json(
        { success: false, confirmRequired: true, code: e.code, error: e.message, details: e.details },
        { status: 409, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/admin/bokju-coupons/allocations/:id/recall] 실패:", e);
    return jsonError("회수 처리 중 오류가 발생했습니다.", 500);
  }
}
