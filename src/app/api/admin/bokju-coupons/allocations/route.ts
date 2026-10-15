// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/allocations
// ISSUED 상태 쿠폰을 업체에 배정(ALLOCATED로 전이). 부분 배정은 허용하지 않고
// 요청 수량만큼 정확히 확보되지 않으면 전체 롤백한다(서비스 레이어에서 보장).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { allocateToPartner, BokjuCouponError } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const campaignId = Number(body.campaignId);
    const partnerId = Number(body.partnerId);
    const qty = Number(body.qty);
    if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");
    if (!Number.isInteger(partnerId)) return jsonError("partnerId가 올바르지 않습니다.");
    if (!Number.isInteger(qty) || qty < 1) return jsonError("qty는 1 이상의 정수여야 합니다.");

    const result = await allocateToPartner(
      {
        campaignId,
        partnerId,
        qty,
        distributeDeadline: body.distributeDeadline ? new Date(body.distributeDeadline) : undefined,
      },
      actor.adminId
    );
    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/allocations] 실패:", e);
    return jsonError("배정 중 오류가 발생했습니다.", 500);
  }
}
