// [AI 쿠폰 디자인 표시·숨김 기능 §6] POST /api/admin/bokju-coupons/design-templates/:id/set-default
// "쿠폰 만들기" 화면의 기본 선택값으로 지정(기존 기본 템플릿은 자동 해제).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { setDefaultDesignTemplate, BokjuDesignTemplateError } from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("기본 템플릿 지정 권한이 없습니다.", 403);

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const updated = await setDefaultDesignTemplate({ id: templateId, actorId: actor.adminId });
    return jsonOk({ ...updated, createdAt: updated.createdAt.toISOString(), updatedAt: updated.updatedAt.toISOString() });
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/design-templates/:id/set-default] 실패:", e);
    return jsonError("기본 템플릿 지정 중 오류가 발생했습니다.", 500);
  }
}
