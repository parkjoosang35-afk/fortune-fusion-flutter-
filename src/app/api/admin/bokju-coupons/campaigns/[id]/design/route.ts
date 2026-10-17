// [쿠폰 디자인 스튜디오 4단계 — 엔드포인트 5종 중 1] GET/PUT
// /api/admin/bokju-coupons/campaigns/:id/design
//
// GET: 캠페인의 "지금 쓰는" 디자인 레이아웃을 돌려준다(없으면 defaultLayout()).
// PUT: 레이아웃을 저장(=발행)한다. [02e §0-G 필수1] 서버가 validateLayout()을
//   다시 돌려 거부할 수 있다 — studio-api.ts의 saveCampaignDesign()이
//   layout.ts의 validateLayout을 그대로 재사용한다(복사 금지).
//   흐름: validateLayout 통과 → freezeRevision → setCurrentRevision
//   (02e §3-3 "디자인 저장 → freezeRevision → setCurrentRevision").
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import {
  getCampaignDesign, saveCampaignDesign, StudioApiError,
} from "@/lib/bokju-coupon-design/studio-api";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

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
    const result = await getCampaignDesign(campaignId);
    return jsonOk(result);
  } catch (e) {
    if (e instanceof StudioApiError) return jsonError(e.message, e.status);
    console.error("[GET /api/admin/bokju-coupons/campaigns/:id/design] 실패:", e);
    return jsonError("디자인 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("디자인 저장 권한이 없습니다.", 403);

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const note = typeof body.note === "string" ? body.note : undefined;

    // [필수1 — 가장 중요] 클라이언트가 "검사 통과"라고 주장해도 여기서
    // 다시 validateLayout()을 돌린다(studio-api.ts 내부). error가 있으면
    // 400으로 거부하고 저장도 발행도 하지 않는다.
    const result = await saveCampaignDesign(campaignId, body.layout, {
      note,
      createdBy: actor.adminId,
    });

    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "DESIGN_SAVE",
      summary: `디자인 저장(rev${result.revisionNo}${result.reused ? ", 기존 리비전 재사용" : ""})`,
    });

    return jsonOk(result, 201);
  } catch (e) {
    if (e instanceof StudioApiError) {
      // [필수1] 레이아웃 검증 실패(LAYOUT_INVALID)는 issues 상세를 함께
      // 내려줘야 에디터가 "무엇이 문제인지" 보여줄 수 있다. jsonError()는
      // message만 받으므로, issues가 있는 경우 body를 직접 구성한다.
      if (e.issues && e.issues.length > 0) {
        return Response.json(
          { success: false, error: e.message, issues: e.issues },
          { status: e.status },
        );
      }
      return jsonError(e.message, e.status);
    }
    console.error("[PUT /api/admin/bokju-coupons/campaigns/:id/design] 실패:", e);
    return jsonError("디자인 저장 중 오류가 발생했습니다.", 500);
  }
}
