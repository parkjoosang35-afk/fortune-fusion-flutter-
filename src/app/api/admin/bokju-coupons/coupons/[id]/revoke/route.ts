// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/coupons/:id/revoke
// 단건 쿠폰 사용 중지(이미 REDEEMED면 거부 — 적립 정정은 지갑 도메인 절차로 별도 처리).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { revokeCoupon, BokjuCouponError } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const couponId = Number(id);
  if (!Number.isInteger(couponId)) return jsonError("couponId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const reason = typeof body.reason === "string" ? body.reason : "관리자 수동 중지";
    const result = await revokeCoupon(couponId, reason);
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/coupons/:id/revoke] 실패:", e);
    return jsonError("쿠폰 중지 중 오류가 발생했습니다.", 500);
  }
}
