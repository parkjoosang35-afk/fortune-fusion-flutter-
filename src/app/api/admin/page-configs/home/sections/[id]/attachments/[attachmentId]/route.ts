// [메인화면 관리자 편집기] PUT/DELETE /admin/page-configs/home/sections/{id}/attachments/{attachmentId}
// PUT: 순서 변경(displayOrder)/대표(primary) 지정 변경. DELETE: 첨부 해제(unbind).
import { prisma } from "@/lib/db";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string; attachmentId: string }> },
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam, attachmentId: attachmentIdParam } = await params;
  const sectionId = Number(idParam);
  const attachmentId = Number(attachmentIdParam);
  if (!Number.isInteger(sectionId) || !Number.isInteger(attachmentId)) {
    return jsonError("id가 올바르지 않습니다.");
  }

  try {
    const attachment = await prisma.sectionAttachmentBinding.findFirst({
      where: { id: attachmentId, sectionId },
    });
    if (!attachment) return jsonError("첨부파일을 찾을 수 없습니다.", 404);

    const body = await request.json();
    if (body.isPrimary === true) {
      await prisma.sectionAttachmentBinding.updateMany({
        where: { sectionId, usageType: attachment.usageType, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    const updated = await prisma.sectionAttachmentBinding.update({
      where: { id: attachmentId },
      data: {
        isPrimary: typeof body.isPrimary === "boolean" ? body.isPrimary : attachment.isPrimary,
        displayOrder: typeof body.displayOrder === "number" ? body.displayOrder : attachment.displayOrder,
      },
    });

    return jsonOk(updated);
  } catch (e) {
    console.error("[PUT .../attachments/[attachmentId]] 실패:", e);
    return jsonError("첨부파일 수정 중 오류가 발생했습니다.", 500);
  }
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string; attachmentId: string }> },
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam, attachmentId: attachmentIdParam } = await params;
  const sectionId = Number(idParam);
  const attachmentId = Number(attachmentIdParam);
  if (!Number.isInteger(sectionId) || !Number.isInteger(attachmentId)) {
    return jsonError("id가 올바르지 않습니다.");
  }

  try {
    const attachment = await prisma.sectionAttachmentBinding.findFirst({
      where: { id: attachmentId, sectionId },
    });
    if (!attachment) return jsonError("첨부파일을 찾을 수 없습니다.", 404);

    await prisma.sectionAttachmentBinding.delete({ where: { id: attachmentId } });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId,
      actionType: "update",
      summary: `첨부파일 해제: usage=${attachment.usageType}`,
    });

    return jsonOk({ id: attachmentId, deleted: true });
  } catch (e) {
    console.error("[DELETE .../attachments/[attachmentId]] 실패:", e);
    return jsonError("첨부파일 해제 중 오류가 발생했습니다.", 500);
  }
}
