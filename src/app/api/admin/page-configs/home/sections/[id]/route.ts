// [메인화면 관리자 편집기] PUT/DELETE /admin/page-configs/home/sections/{id}
// PUT: 스타일 프리셋/블록타입/자산연결 필드 등 상세 편집 전반(§14-3 섹션 상세편집).
// DELETE: soft delete(§6 원칙 - 완전 삭제 최소화). isRequired 섹션은 archived까지만
// 허용하고 실제 deletedAt 처리는 막는다(§18 "필수 섹션은 완전 삭제 불가").
import { prisma } from "@/lib/db";
import {
  isValidAlignmentPreset,
  isValidBackgroundPreset,
  isValidBlockType,
  isValidDensityPreset,
  isValidStylePreset,
  PLATFORM_TARGETS,
  validateSectionContent,
} from "@/lib/page-config-constants";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, serializeSection, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

async function loadSection(id: number) {
  return prisma.pageSection.findFirst({
    where: { id, deletedAt: null },
    include: { attachments: true, displayRules: true },
  });
}

export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const existing = await loadSection(id);
    if (!existing) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const body = await request.json();
    const data: Record<string, unknown> = {};

    if (body.blockType !== undefined) {
      if (!isValidBlockType(body.blockType)) return jsonError("blockType이 올바르지 않습니다.");
      data.blockType = body.blockType;
    }
    if (body.stylePreset !== undefined) {
      if (!isValidStylePreset(body.stylePreset)) return jsonError("stylePreset이 올바르지 않습니다.");
      data.stylePreset = body.stylePreset;
    }
    if (body.backgroundPreset !== undefined) {
      if (!isValidBackgroundPreset(body.backgroundPreset)) return jsonError("backgroundPreset이 올바르지 않습니다.");
      data.backgroundPreset = body.backgroundPreset;
    }
    if (body.alignmentPreset !== undefined) {
      if (!isValidAlignmentPreset(body.alignmentPreset)) return jsonError("alignmentPreset이 올바르지 않습니다.");
      data.alignmentPreset = body.alignmentPreset;
    }
    if (body.densityPreset !== undefined) {
      if (!isValidDensityPreset(body.densityPreset)) return jsonError("densityPreset이 올바르지 않습니다.");
      data.densityPreset = body.densityPreset;
    }
    if (body.buttonLink !== undefined) data.buttonLink = body.buttonLink || null;
    if (body.linkedAssetType !== undefined) data.linkedAssetType = body.linkedAssetType || null;
    if (body.linkedFeatureScope !== undefined) data.linkedFeatureScope = body.linkedFeatureScope || null;
    if (body.linkedCampaignId !== undefined) data.linkedCampaignId = body.linkedCampaignId || null;
    if (body.linkedProductId !== undefined) data.linkedProductId = body.linkedProductId || null;
    if (body.platformTargets !== undefined) {
      if (body.platformTargets === null) {
        data.platformTargets = null;
      } else if (
        Array.isArray(body.platformTargets) &&
        body.platformTargets.every((p: unknown) => (PLATFORM_TARGETS as readonly string[]).includes(p as string))
      ) {
        data.platformTargets = JSON.stringify(body.platformTargets);
      } else {
        return jsonError("platformTargets는 ios/android/web 배열이어야 합니다.");
      }
    }

    // 텍스트 필드도 함께 왔다면 길이 validation(§4, §18 malformed config 방지)
    const contentErrors = validateSectionContent({
      title: body.title ?? existing.title,
      subtitle: body.subtitle ?? existing.subtitle,
      description: body.description ?? existing.description,
      buttonText: body.buttonText ?? existing.buttonText,
      badgeText: body.badgeText ?? existing.badgeText,
      emptyStateText: body.emptyStateText ?? existing.emptyStateText,
    });
    if (contentErrors.length > 0) return jsonError(contentErrors.join(" / "));

    if (body.title !== undefined) data.title = body.title || null;
    if (body.subtitle !== undefined) data.subtitle = body.subtitle || null;
    if (body.description !== undefined) data.description = body.description || null;
    if (body.buttonText !== undefined) data.buttonText = body.buttonText || null;
    if (body.badgeText !== undefined) data.badgeText = body.badgeText || null;
    if (body.emptyStateText !== undefined) data.emptyStateText = body.emptyStateText || null;

    data.updatedBy = actor.adminId;

    const updated = await prisma.pageSection.update({
      where: { id },
      data,
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: id,
      actionType: "update",
      summary: `섹션 수정: ${existing.sectionKey}`,
      payload: data,
    });

    return jsonOk(serializeSection(updated));
  } catch (e) {
    console.error("[PUT /api/admin/page-configs/home/sections/[id]] 실패:", e);
    return jsonError("섹션 수정 중 오류가 발생했습니다.", 500);
  }
}

export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const existing = await loadSection(id);
    if (!existing) return jsonError("섹션을 찾을 수 없습니다.", 404);

    if (existing.isRequired) {
      // §18 필수 섹션 보호: 완전 삭제/보관(archived) 모두 금지하고 hidden까지만 허용
      // (visibility 엔드포인트의 "필수 섹션은 archived 불가" 규칙과 동일하게 유지).
      const hidden = await prisma.pageSection.update({
        where: { id },
        data: { status: "hidden", isVisible: false, updatedBy: actor.adminId },
      });
      await writeAuditLog({
        adminId: actor.adminId,
        pageKey: PAGE_KEY,
        sectionId: id,
        actionType: "hide",
        summary: `필수 섹션은 완전 삭제할 수 없어 hidden으로 전환: ${existing.sectionKey}`,
      });
      return jsonOk({
        ...serializeSection({ ...hidden, attachments: [], displayRules: [] }),
        notice: "필수 섹션은 완전 삭제할 수 없어 숨김(hidden) 처리되었습니다.",
      });
    }

    await prisma.pageSection.update({
      where: { id },
      data: { deletedAt: new Date(), status: "archived", isVisible: false, updatedBy: actor.adminId },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: id,
      actionType: "delete",
      summary: `섹션 삭제(soft delete): ${existing.sectionKey}`,
    });

    return jsonOk({ id, deleted: true });
  } catch (e) {
    console.error("[DELETE /api/admin/page-configs/home/sections/[id]] 실패:", e);
    return jsonError("섹션 삭제 중 오류가 발생했습니다.", 500);
  }
}
