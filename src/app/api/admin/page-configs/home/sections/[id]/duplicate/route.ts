// [메인화면 관리자 편집기] POST /admin/page-configs/home/sections/{id}/duplicate
// §3 "섹션 복제" — 동일 draft 버전 안에 attachments/displayRules까지 포함해 복제.
// sectionKey는 원본과 겹치지 않도록 "_copy_<timestamp>" 접미사를 붙인다.
import { prisma } from "@/lib/db";
import { cloneSectionIntoVersion, isAdminActor, jsonError, jsonOk, requireAdminOrResponse, serializeSection, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function POST(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const existing = await prisma.pageSection.findFirst({
      where: { id, deletedAt: null },
      include: { attachments: true, displayRules: true },
    });
    if (!existing) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const maxOrder = await prisma.pageSection.aggregate({
      where: { pageVersionId: existing.pageVersionId, deletedAt: null },
      _max: { sortOrder: true },
    });

    const duplicated = await cloneSectionIntoVersion(existing, existing.pageVersionId, {
      sectionKey: `${existing.sectionKey}_copy_${Date.now()}`,
      sortOrder: (maxOrder._max.sortOrder ?? existing.sortOrder) + 1,
    });

    // 복제본은 필수 섹션 보호 대상이 아니다(원본만 보호 대상).
    const finalized = await prisma.pageSection.update({
      where: { id: duplicated.id },
      data: { isRequired: false, title: existing.title ? `${existing.title} (복제)` : existing.title },
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: finalized.id,
      actionType: "duplicate",
      summary: `섹션 복제: ${existing.sectionKey} -> ${finalized.sectionKey}`,
    });

    return jsonOk(serializeSection(finalized), 201);
  } catch (e) {
    console.error("[POST .../duplicate] 실패:", e);
    return jsonError("섹션 복제 중 오류가 발생했습니다.", 500);
  }
}
