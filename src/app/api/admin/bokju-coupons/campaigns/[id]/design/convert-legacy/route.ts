// [쿠폰 디자인 스튜디오 4단계 — 작업순서4(§4-3) 전환 버튼] POST
// /api/admin/bokju-coupons/campaigns/:id/design/convert-legacy
//
// 기존 11토글 캠페인을 신규 DesignLayout 체계로 1회 변환한다
// (studio-api.ts의 convertLegacyDesign()이 실제 로직 — 이 파일은
// 요청 파싱·인증가드·HTTP 응답 포맷팅만 담당하는 얇은 껍데기,
// design/route.ts 등 기존 4종 엔드포인트와 동일한 관행).
//
// [자동 전환 절대 금지 — 02e §4-3] 이 라우트는 관리자의 명시적 POST
// 요청(= 버튼 클릭)으로만 호출된다. 어떤 배치/크론/발행 흐름도 이
// 엔드포인트를 호출하지 않는다.
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { convertLegacyDesign, StudioApiError } from "@/lib/bokju-coupon-design/studio-api";
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
  if (!canWrite(actor.roleCode)) return jsonError("디자인 전환 권한이 없습니다.", 403);

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const result = await convertLegacyDesign(campaignId, { createdBy: actor.adminId });

    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "DESIGN_CONVERT_LEGACY",
      summary: `레거시 11토글 설정을 신규 디자인으로 전환(rev${result.revisionNo})`,
    });

    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof StudioApiError) {
      if (e.issues && e.issues.length > 0) {
        return Response.json(
          { success: false, error: e.message, issues: e.issues },
          { status: e.status },
        );
      }
      return jsonError(e.message, e.status);
    }
    console.error("[POST /api/admin/bokju-coupons/campaigns/:id/design/convert-legacy] 실패:", e);
    return jsonError("디자인 전환 중 오류가 발생했습니다.", 500);
  }
}
