// [메인화면 관리자 편집기] PUT /admin/page-configs/home/sections/{id}/content
// §4 텍스트 편집 전용 엔드포인트 — title/subtitle/description/buttonText/badgeText/
// emptyStateText/buttonLink만 다룬다(스타일/조건/스케줄은 별도 엔드포인트).
import { prisma } from "@/lib/db";
import { validateSectionContent } from "@/lib/page-config-constants";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, serializeSection, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const existing = await prisma.pageSection.findFirst({ where: { id, deletedAt: null } });
    if (!existing) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const body = await request.json();
    const next = {
      title: body.title !== undefined ? body.title || null : existing.title,
      subtitle: body.subtitle !== undefined ? body.subtitle || null : existing.subtitle,
      description: body.description !== undefined ? body.description || null : existing.description,
      buttonText: body.buttonText !== undefined ? body.buttonText || null : existing.buttonText,
      badgeText: body.badgeText !== undefined ? body.badgeText || null : existing.badgeText,
      emptyStateText: body.emptyStateText !== undefined ? body.emptyStateText || null : existing.emptyStateText,
    };

    const errors = validateSectionContent(next);
    if (errors.length > 0) return jsonError(errors.join(" / "));

    const updated = await prisma.pageSection.update({
      where: { id },
      data: {
        ...next,
        buttonLink: body.buttonLink !== undefined ? body.buttonLink || null : existing.buttonLink,
        updatedBy: actor.adminId,
      },
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: id,
      actionType: "update",
      summary: `섹션 텍스트 수정: ${existing.sectionKey}`,
      payload: next,
    });

    return jsonOk(serializeSection(updated));
  } catch (e) {
    console.error("[PUT .../content] 실패:", e);
    return jsonError("텍스트 수정 중 오류가 발생했습니다.", 500);
  }
}
