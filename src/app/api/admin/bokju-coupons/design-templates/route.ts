// [AI 쿠폰 디자인 표시·숨김 기능 §6] GET/POST /api/admin/bokju-coupons/design-templates
// GET: 템플릿 목록(캠페인 생성 화면의 "저장된 템플릿" 선택지 + 템플릿 관리 화면 공용).
//      ?includeArchived=1 이면 사용 중지된 템플릿도 포함(관리 화면 전용).
// POST: 새 템플릿 생성(배경 선택 + 11개 표시/숨김 설정).
import { NextRequest } from "next/server";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { RBAC_MATRIX, type AdminRoleCode } from "@/lib/rbac";
import {
  listDesignTemplates,
  createDesignTemplate,
  BokjuDesignTemplateError,
} from "@/lib/bokju-coupon-design-template-service";

export const dynamic = "force-dynamic";

function canWrite(roleCode: string): boolean {
  return !!RBAC_MATRIX.bokju_coupon[roleCode as AdminRoleCode]?.write;
}

function serialize(t: Awaited<ReturnType<typeof listDesignTemplates>>[number]) {
  return { ...t, createdAt: t.createdAt.toISOString(), updatedAt: t.updatedAt.toISOString() };
}

export async function GET(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const includeArchived = request.nextUrl.searchParams.get("includeArchived") === "1";
    const templates = await listDesignTemplates({ includeArchived });
    return jsonOk({ templates: templates.map(serialize) });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/design-templates] 실패:", e);
    return jsonError("디자인 템플릿 목록 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: NextRequest) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;
  if (!canWrite(actor.roleCode)) return jsonError("템플릿 생성 권한이 없습니다.", 403);

  try {
    const body = await request.json().catch(() => ({}));
    const name = typeof body.name === "string" ? body.name.trim() : "";
    if (!name) return jsonError("템플릿 이름을 입력해 주세요.");

    const visibility = body.visibility && typeof body.visibility === "object" ? body.visibility : {};
    const designAssetId =
      body.designAssetId === null || body.designAssetId === undefined
        ? null
        : Number(body.designAssetId);
    if (designAssetId !== null && !Number.isInteger(designAssetId)) {
      return jsonError("designAssetId가 올바르지 않습니다.");
    }

    const created = await createDesignTemplate({
      name,
      designAssetId,
      visibility,
      isDefault: body.isDefault === true,
      actorId: actor.adminId,
    });
    return jsonOk(serialize(created), 201);
  } catch (e) {
    if (e instanceof BokjuDesignTemplateError) return jsonError(e.message, 400);
    console.error("[POST /api/admin/bokju-coupons/design-templates] 실패:", e);
    return jsonError("템플릿 생성 중 오류가 발생했습니다.", 500);
  }
}
