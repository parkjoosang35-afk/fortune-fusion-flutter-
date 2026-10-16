// [AI 쿠폰 디자인 표시·숨김 기능 §6/§9] GET/PATCH/DELETE
// /api/admin/bokju-coupons/design-templates/:id
// GET: 단건 조회(관리 화면 상세/수정 폼 로딩).
// PATCH: 이름/배경/표시설정/기본여부 수정(§6 "템플릿 편집" — 이미 발행된 쿠폰
//        이미지는 소급 변경되지 않음, updateDesignTemplate() 주석 참고).
// DELETE: 삭제(§9 "사용 중인 템플릿은 연결된 쿠폰 확인 후에만" — 캠페인이
//        연결돼 있으면 TEMPLATE_IN_USE로 차단하고 "사용 중지"를 안내).
import { NextRequest } from "next/server";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import {
  getDesignTemplate,
  updateDesignTemplate,
  deleteDesignTemplate,
  BokjuDesignTemplateError,
} from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

function serialize(t: NonNullable<Awaited<ReturnType<typeof getDesignTemplate>>>) {
  return { ...t, createdAt: t.createdAt.toISOString(), updatedAt: t.updatedAt.toISOString() };
}

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const template = await getDesignTemplate(templateId);
    if (!template) return jsonError("템플릿을 찾을 수 없습니다.", 404);
    return jsonOk(serialize(template));
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/design-templates/:id] 실패:", e);
    return jsonError("템플릿 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("템플릿 수정 권한이 없습니다.", 403);

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const body = await request.json().catch(() => ({}));
    const designAssetId =
      body.designAssetId === undefined
        ? undefined
        : body.designAssetId === null
          ? null
          : Number(body.designAssetId);
    if (designAssetId !== undefined && designAssetId !== null && !Number.isInteger(designAssetId)) {
      return jsonError("designAssetId가 올바르지 않습니다.");
    }

    const updated = await updateDesignTemplate({
      id: templateId,
      name: typeof body.name === "string" ? body.name : undefined,
      designAssetId,
      visibility: body.visibility && typeof body.visibility === "object" ? body.visibility : undefined,
      isDefault: typeof body.isDefault === "boolean" ? body.isDefault : undefined,
      actorId: actor.adminId,
    });
    return jsonOk(serialize(updated));
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[PATCH /api/admin/bokju-coupons/design-templates/:id] 실패:", e);
    return jsonError("템플릿 수정 중 오류가 발생했습니다.", 500);
  }
}

export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("템플릿 삭제 권한이 없습니다.", 403);

  const { id } = await params;
  const templateId = Number(id);
  if (!Number.isInteger(templateId)) return jsonError("templateId가 올바르지 않습니다.");

  try {
    const result = await deleteDesignTemplate({ id: templateId, actorId: actor.adminId });
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[DELETE /api/admin/bokju-coupons/design-templates/:id] 실패:", e);
    return jsonError("템플릿 삭제 중 오류가 발생했습니다.", 500);
  }
}
