// [메인화면 관리자 편집기] PUT /admin/page-configs/home/sections/{id}/visibility
// §3/§6 활성/비활성, 숨김/노출, 보관 상태 전환. isRequired 섹션은 archived로
// 전환할 수 없다(§18 "필수 섹션은 완전 삭제 불가" - 완전 비노출도 막음, hidden까지만 허용).
import { prisma } from "@/lib/db";
import { isValidSectionStatus } from "@/lib/page-config-constants";
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
    const status = typeof body.status === "string" ? body.status : undefined;
    if (status !== undefined && !isValidSectionStatus(status)) {
      return jsonError("status는 visible/hidden/archived 중 하나여야 합니다.");
    }
    if (status === "archived" && existing.isRequired) {
      return jsonError("필수 섹션(오늘의 운세 등)은 보관(archived) 처리할 수 없습니다. 숨김(hidden)까지만 가능합니다.");
    }

    const isVisible = typeof body.isVisible === "boolean" ? body.isVisible : status ? status === "visible" : existing.isVisible;

    const updated = await prisma.pageSection.update({
      where: { id },
      data: {
        status: status ?? existing.status,
        isVisible,
        updatedBy: actor.adminId,
      },
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: id,
      actionType: status === "hidden" ? "hide" : status === "archived" ? "archive" : "update",
      summary: `섹션 노출 상태 변경: ${existing.sectionKey} -> ${status ?? existing.status}`,
    });

    return jsonOk(serializeSection(updated));
  } catch (e) {
    console.error("[PUT .../visibility] 실패:", e);
    return jsonError("노출 상태 변경 중 오류가 발생했습니다.", 500);
  }
}
