// [쿠폰 디자인 스튜디오 4단계 — 02i §필수2 "(A) 전환 취소 경로"] POST
// /api/admin/bokju-coupons/campaigns/:id/design/revert-to-legacy
//
// convert-legacy의 역방향: campaign.currentDesignRevisionId 포인터를 다시
// null로 되돌려 레거시 11토글 화면으로 복귀한다(studio-api.ts의
// revertToLegacyDesign()이 실제 로직 — 이 파일은 요청 파싱·인증가드·HTTP
// 응답 포맷팅만 담당하는 얇은 껍데기, 기존 4종 엔드포인트와 동일한 관행).
//
// [전환과 동일하게 수동 1회 액션] 이 라우트도 관리자의 명시적 POST
// 요청(= "레거시로 되돌리기" 버튼 클릭)으로만 호출된다. 어떤 배치/크론/
// 발행 흐름도 이 엔드포인트를 호출하지 않는다.
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { revertToLegacyDesign, StudioApiError } from "@/lib/bokju-coupon-design/studio-api";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("되돌리기 권한이 없습니다.", 403);

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const result = await revertToLegacyDesign(campaignId);

    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "DESIGN_REVERT_TO_LEGACY",
      summary: "신규 디자인 전환을 취소하고 레거시(11토글) 설정으로 되돌림",
    });

    return jsonOk(result);
  } catch (e) {
    if (e instanceof StudioApiError) return jsonError(e.message, e.status);
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/design/revert-to-legacy] 실패:", e);
    return jsonError("되돌리기 중 오류가 발생했습니다.", 500);
  }
}
