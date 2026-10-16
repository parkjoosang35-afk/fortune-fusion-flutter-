// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/campaigns/:id/reassign
// 회수(RECALLED)된 쿠폰을 다른 업체에 재배정한다(§9/§22.6). RECALLED + 미사용 +
// 미배정 쿠폰만 대상이며, 부분 재배정은 허용하지 않는다(서비스 레이어가 보장).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { reassignRecalledCoupons, BokjuCouponError } from "@/lib/bokju-coupon-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const body = await request.json();
    const newPartnerId = Number(body.newPartnerId);
    const qty = Number(body.qty);
    if (!Number.isInteger(newPartnerId)) return jsonError("newPartnerId가 올바르지 않습니다.");
    if (!Number.isInteger(qty) || qty < 1) return jsonError("qty는 1 이상의 정수여야 합니다.");

    const result = await reassignRecalledCoupons(
      {
        campaignId,
        newPartnerId,
        qty,
        distributeDeadline: body.distributeDeadline ? new Date(body.distributeDeadline) : undefined,
      },
      actor.adminId
    );
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "ALLOCATION",
      targetId: result.allocationId,
      actionType: "REASSIGN",
      summary: `회수 쿠폰 ${result.reassignedQty}장을 업체(${newPartnerId})에 재배정`,
    });
    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/reassign] 실패:", e);
    return jsonError("재배정 중 오류가 발생했습니다.", 500);
  }
}
