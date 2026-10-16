// [AI 쿠폰 디자인 표시·숨김 기능 §6] POST /api/admin/bokju-coupons/design-templates/:id/duplicate
// 기존 템플릿을 복사해 새 템플릿으로 저장(§6 "기존 것을 복사해서 새로 저장").
import { NextRequest } from "next/server";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import { duplicateDesignTemplate, BokjuDesignTemplateError } from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("템플릿 복사 권한이 없습니다.", 403);

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const created = await duplicateDesignTemplate({
      sourceId: templateId,
      newName: typeof body.newName === "string" ? body.newName : undefined,
      actorId: actor.adminId,
    });
    return jsonOk({ ...created, createdAt: created.createdAt.toISOString(), updatedAt: created.updatedAt.toISOString() }, 201);
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/design-templates/:id/duplicate] 실패:", e);
    return jsonError("템플릿 복사 중 오류가 발생했습니다.", 500);
  }
}
