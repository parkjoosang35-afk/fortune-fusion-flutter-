// [메인화면 관리자 편집기] DELETE /admin/page-configs/home/sections/{id}/conditions/{ruleId}
import { prisma } from "@/lib/db";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string; ruleId: string }> },
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam, ruleId: ruleIdParam } = await params;
  const sectionId = Number(idParam);
  const ruleId = Number(ruleIdParam);
  if (!Number.isInteger(sectionId) || !Number.isInteger(ruleId)) {
    return jsonError("id가 올바르지 않습니다.");
  }

  try {
    const rule = await prisma.sectionDisplayRule.findFirst({ where: { id: ruleId, sectionId } });
    if (!rule) return jsonError("노출 조건을 찾을 수 없습니다.", 404);

    await prisma.sectionDisplayRule.delete({ where: { id: ruleId } });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId,
      actionType: "update",
      summary: `노출 조건 삭제: ${rule.ruleType} ${rule.ruleOperator} ${rule.ruleValue}`,
    });

    return jsonOk({ id: ruleId, deleted: true });
  } catch (e) {
    console.error("[DELETE .../conditions/[ruleId]] 실패:", e);
    return jsonError("노출 조건 삭제 중 오류가 발생했습니다.", 500);
  }
}
