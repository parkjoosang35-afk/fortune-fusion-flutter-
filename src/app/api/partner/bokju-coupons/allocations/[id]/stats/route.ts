// [복주머니 마케팅 쿠폰] GET /api/partner/bokju-coupons/allocations/:id/stats
// 업체 보고치(reportedQty)와 시스템 확인치(redeemedQty)를 절대 합치지 않고 분리 반환.
import { jsonError, jsonOk } from "@/lib/page-config-helpers";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { myStats, BokjuCouponError, type PartnerScope } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await requirePartnerOrResponse();
  if (!isPartnerSession(session)) return session;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) return jsonError("allocationId가 올바르지 않습니다.");

  const scope: PartnerScope = { partnerId: session.partnerId, accountId: session.accountId, role: session.role };

  try {
    const stats = await myStats(scope, allocationId);
    return jsonOk(stats);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, e.code === "PARTNER_FORBIDDEN" ? 403 : 400);
    console.error("[GET /api/partner/bokju-coupons/allocations/:id/stats] 실패:", e);
    return jsonError("통계 조회 중 오류가 발생했습니다.", 500);
  }
}
