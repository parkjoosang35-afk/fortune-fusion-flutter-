// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/coupons/bulk-delete
// 다건 쿠폰 삭제. body: { couponIds: number[] }
// 부분 실패를 허용한다 — 이미 적립된 쿠폰이 섞여 있어도 나머지는 삭제하고
// skipped 목록으로 사유를 함께 반환한다(bulkDeleteCoupons() 참고).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { bulkDeleteCoupons, BokjuCouponError } from "@/lib/bokju-coupon-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json().catch(() => ({}));
    const couponIds = Array.isArray(body.couponIds)
      ? body.couponIds.map((v: unknown) => Number(v)).filter((v: number) => Number.isInteger(v))
      : [];
    if (couponIds.length === 0) return jsonError("삭제할 쿠폰 ID 목록이 필요합니다.");

    const result = await bulkDeleteCoupons(couponIds);
    await writeCouponAuditLog({
      actorId: actor.adminId,
      targetType: "COUPON",
      actionType: "BULK_DELETE",
      summary: `쿠폰 ${result.deletedCount}장 일괄 삭제` + (result.skipped.length > 0 ? ` (스킵 ${result.skipped.length}건)` : ""),
      payload: { requestedCount: couponIds.length, deletedCount: result.deletedCount, skipped: result.skipped },
    });
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/coupons/bulk-delete] 실패:", e);
    return jsonError("쿠폰 일괄 삭제 중 오류가 발생했습니다.", 500);
  }
}
