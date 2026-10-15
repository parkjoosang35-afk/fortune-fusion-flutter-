// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/allocations/:id/deliver
// 관리자가 실물(쿠폰 카드/스티커 등)을 업체에 발송 완료 처리(ALLOCATED→DELIVERED).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { markDelivered, BokjuCouponError } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) return jsonError("allocationId가 올바르지 않습니다.");

  try {
    const result = await markDelivered(allocationId);
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/allocations/:id/deliver] 실패:", e);
    return jsonError("배송 확인 처리 중 오류가 발생했습니다.", 500);
  }
}
