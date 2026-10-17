// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 2-되돌리기] POST
// /api/admin/bokju-coupons/campaigns/:id/design/revisions/:revisionId/rollback
//
// 캠페인의 "현재 리비전" 포인터를 과거 리비전으로 되돌린다(setCurrentRevision
// 재사용 — revision.ts에는 "되돌리기" 전용 함수가 없고 포인터 교체 하나로
// 충분하다는 것이 02d 3단계의 설계였다).
//
// [02e §0-G 필수 4] 응답에 "이미 발행된 쿠폰은 유지됨" + "신규 발행분만
// 영향받음" 두 사실을 함께 내려준다 — 에디터(React)가 이 notice를 그대로
// 화면에 표시해야 한다(관리자가 "기존 쿠폰도 바뀌었겠지"라고 오해하는 것을
// 막기 위함).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { rollbackCampaignDesign, StudioApiError } from "@/lib/bokju-coupon-design/studio-api";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string; revisionId: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("되돌리기 권한이 없습니다.", 403);

  const { id, revisionId } = await params;
  const campaignId = Number(id);
  const revId = Number(revisionId);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");
  if (!Number.isInteger(revId)) return jsonError("revisionId가 올바르지 않습니다.");

  try {
    const result = await rollbackCampaignDesign(campaignId, revId);
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "DESIGN_ROLLBACK",
      summary: `디자인 되돌리기 → rev${result.revisionNo}`,
    });
    return jsonOk(result);
  } catch (e) {
    if (e instanceof StudioApiError) return jsonError(e.message, e.status);
    console.error("[POST .../design/revisions/:revisionId/rollback] 실패:", e);
    return jsonError("되돌리기 중 오류가 발생했습니다.", 500);
  }
}
