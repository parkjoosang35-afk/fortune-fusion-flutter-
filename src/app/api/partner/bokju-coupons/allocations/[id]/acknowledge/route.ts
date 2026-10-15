// [복주머니 마케팅 쿠폰] POST /api/partner/bokju-coupons/allocations/:id/acknowledge
// 업체가 "실물 쿠폰을 받았음"을 확인. 서비스 레이어가 partnerId 일치 여부를
// WHERE절로 직접 검증하므로(updateMany count===0 → PARTNER_FORBIDDEN) 타 업체 배정
// 접근이 원천 차단된다.
import { jsonError, jsonOk } from "@/lib/page-config-helpers";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { acknowledgeAllocation, BokjuCouponError, type PartnerScope } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(
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
    const result = await acknowledgeAllocation(scope, allocationId);
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, e.code === "PARTNER_FORBIDDEN" ? 403 : 400);
    console.error("[POST /api/partner/bokju-coupons/allocations/:id/acknowledge] 실패:", e);
    return jsonError("확인 처리 중 오류가 발생했습니다.", 500);
  }
}
