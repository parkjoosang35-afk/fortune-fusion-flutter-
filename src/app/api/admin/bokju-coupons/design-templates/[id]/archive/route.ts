// [AI 쿠폰 디자인 표시·숨김 기능 §6/§9] POST /api/admin/bokju-coupons/design-templates/:id/archive
// body: { archived: boolean } — true면 "사용 중지"(발행 화면 선택 목록에서만
// 숨김, 기존 캠페인 렌더링에는 영향 없음), false면 "사용 재개".
import { NextRequest } from "next/server";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { setDesignTemplateArchived, BokjuDesignTemplateError } from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("템플릿 상태 변경 권한이 없습니다.", 403);

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const archived = body.archived !== false; // 기본값 true(명시적으로 false를 줘야 "재개")
    const updated = await setDesignTemplateArchived({ id: templateId, archived, actorId: actor.adminId });
    return jsonOk({ ...updated, createdAt: updated.createdAt.toISOString(), updatedAt: updated.updatedAt.toISOString() });
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/design-templates/:id/archive] 실패:", e);
    return jsonError("템플릿 상태 변경 중 오류가 발생했습니다.", 500);
  }
}
