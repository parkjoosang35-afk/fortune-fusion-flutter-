// [복주머니 마케팅 쿠폰] POST /api/admin/bokju-coupons/campaigns/:id/issue
// ACTIVE 캠페인에 쿠폰 N장 대량 발행(쿠폰번호/등록토큰 중복은 서비스 레이어가 재시도로 흡수).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { issueCoupons, BokjuCouponError } from "@/lib/bokju-coupon-service";
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
    const count = Number(body.count);
    if (!Number.isInteger(count) || count < 1) return jsonError("count는 1 이상의 정수여야 합니다.");

    const result = await issueCoupons(campaignId, count, actor.adminId);
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "ISSUE",
      summary: `쿠폰 ${result.issued}장 발행`,
    });
    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/issue] 실패:", e);
    return jsonError("쿠폰 발행 중 오류가 발생했습니다.", 500);
  }
}
