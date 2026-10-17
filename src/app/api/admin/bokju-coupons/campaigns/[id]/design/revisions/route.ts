// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 2] GET
// /api/admin/bokju-coupons/campaigns/:id/design/revisions
// 캠페인의 전체 디자인 리비전 이력(최신순) + 어느 것이 "현재" 리비전인지.
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { listCampaignRevisions, StudioApiError } from "@/lib/bokju-coupon-design/studio-api";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const revisions = await listCampaignRevisions(campaignId);
    return jsonOk({ revisions });
  } catch (e) {
    if (e instanceof StudioApiError) return jsonError(e.message, e.status);
    console.error("[GET /api/admin/bokju-coupons/campaigns/:id/design/revisions] 실패:", e);
    return jsonError("리비전 목록 조회 중 오류가 발생했습니다.", 500);
  }
}
