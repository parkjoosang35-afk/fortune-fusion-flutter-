// [복주머니 마케팅 쿠폰] PATCH /api/admin/bokju-coupons/campaigns/:id/status
// DRAFT→ACTIVE(발행 시작), ACTIVE↔PAUSED(일시중지/재개), ACTIVE/PAUSED→CLOSED(종료).
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  DRAFT: ["ACTIVE", "CLOSED"],
  ACTIVE: ["PAUSED", "CLOSED"],
  PAUSED: ["ACTIVE", "CLOSED"],
  CLOSED: [],
};

export async function PATCH(
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
    const nextStatus = typeof body.status === "string" ? body.status : "";
    if (!["DRAFT", "ACTIVE", "PAUSED", "CLOSED"].includes(nextStatus)) {
      return jsonError("status는 DRAFT/ACTIVE/PAUSED/CLOSED 중 하나여야 합니다.");
    }

    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

    const allowed = ALLOWED_TRANSITIONS[campaign.status] ?? [];
    if (!allowed.includes(nextStatus)) {
      return jsonError(`${campaign.status} 상태에서 ${nextStatus}(으)로 전이할 수 없습니다.`);
    }

    const updated = await prisma.bokjuCouponCampaign.update({
      where: { id: campaignId },
      data: { status: nextStatus },
    });
    return jsonOk({ id: updated.id, status: updated.status });
  } catch (e) {
    console.error("[PATCH /api/admin/bokju-coupons/campaigns/:id/status] 실패:", e);
    return jsonError("상태 변경 중 오류가 발생했습니다.", 500);
  }
}
