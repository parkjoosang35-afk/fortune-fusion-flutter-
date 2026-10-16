// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/coupons/:id/delete
// 단건 쿠폰 실제 삭제(hard delete). 기존 .../revoke/route.ts(사용 중지, soft)와는
// 별개 — 이미 적립(REDEEMED)된 쿠폰은 deleteCoupon()에서 거부된다.
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { deleteCoupon, BokjuCouponError } from "@/lib/bokju-coupon-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const couponId = Number(id);
  if (!Number.isInteger(couponId)) return jsonError("couponId가 올바르지 않습니다.");

  try {
    const result = await deleteCoupon(couponId);
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId: result.campaignId,
      targetType: "COUPON",
      targetId: couponId,
      actionType: "DELETE",
      summary: `쿠폰 삭제: ${result.couponNo}`,
    });
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/coupons/:id/delete] 실패:", e);
    return jsonError("쿠폰 삭제 중 오류가 발생했습니다.", 500);
  }
}
