// [복주머니 마케팅 쿠폰] POST /api/partner/bokju-coupons/allocations/:id/report
// 업체가 "실제로 몇 장 나눠줬는지" 자체 보고. 누적 보고량이 배정 수량을 넘으면
// REPORT_EXCEEDED로 거부한다(서비스 레이어가 직접 합산 검증).
import { jsonError, jsonOk } from "@/lib/page-config-helpers";
import { requirePartnerOrResponse, isPartnerSession } from "@/lib/partner-session";
import { reportDistribution, BokjuCouponError, type PartnerScope } from "@/lib/bokju-coupon-service";

export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await requirePartnerOrResponse();
  if (!isPartnerSession(session)) return session;

  const { id } = await params;
  const allocationId = Number(id);
  if (!Number.isInteger(allocationId)) return jsonError("allocationId가 올바르지 않습니다.");

  const scope: PartnerScope = { partnerId: session.partnerId, accountId: session.accountId, role: session.role };

  try {
    const body = await request.json();
    const qty = Number(body.qty);
    if (!Number.isInteger(qty) || qty < 1) return jsonError("qty는 1 이상의 정수여야 합니다.");
    if (!body.date) return jsonError("date는 필수입니다.");
    const method = typeof body.method === "string" && body.method ? body.method : "ETC";

    const result = await reportDistribution(scope, allocationId, {
      qty,
      date: new Date(body.date),
      method,
      note: typeof body.note === "string" ? body.note : undefined,
    });
    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof BokjuCouponError) {
      const status = e.code === "PARTNER_FORBIDDEN" ? 403 : e.code === "REPORT_EXCEEDED" ? 409 : 400;
      return jsonError(e.message, status);
    }
    console.error("[POST /api/partner/bokju-coupons/allocations/:id/report] 실패:", e);
    return jsonError("보고 처리 중 오류가 발생했습니다.", 500);
  }
}
