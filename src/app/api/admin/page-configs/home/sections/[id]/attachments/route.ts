// [메인화면 관리자 편집기] GET/POST /admin/page-configs/home/sections/{id}/attachments
// §10 첨부파일/배너/아이콘 연동 — 실제 파일 업로드는 기존 /api/upload(category=page-configs)를
// 재사용하고, 이 엔드포인트는 "업로드된 URL을 섹션에 바인딩(binding)"하는 역할만 한다
// (같은 파일 업로드 인프라를 중복 구현하지 않음 - 이 프로젝트의 일관된 원칙).
import { prisma } from "@/lib/db";
import { isValidAttachmentUsageType } from "@/lib/page-config-constants";
import { isAdminActor, jsonError, jsonOk, requireAdminOrResponse, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const sectionId = Number(idParam);
  if (!Number.isInteger(sectionId)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const attachments = await prisma.sectionAttachmentBinding.findMany({
      where: { sectionId },
      orderBy: { displayOrder: "asc" },
    });
    return jsonOk(attachments);
  } catch (e) {
    console.error("[GET .../attachments] 실패:", e);
    return jsonError("첨부파일 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id: idParam } = await params;
  const sectionId = Number(idParam);
  if (!Number.isInteger(sectionId)) return jsonError("섹션 id가 올바르지 않습니다.");

  try {
    const section = await prisma.pageSection.findFirst({ where: { id: sectionId, deletedAt: null } });
    if (!section) return jsonError("섹션을 찾을 수 없습니다.", 404);

    const body = await request.json();
    const attachmentUrl = typeof body.attachmentUrl === "string" ? body.attachmentUrl.trim() : "";
    const usageType = typeof body.usageType === "string" ? body.usageType : "";
    const isPrimary = body.isPrimary === true;

    if (!attachmentUrl) return jsonError("attachmentUrl은 필수입니다.");
    if (!isValidAttachmentUsageType(usageType)) return jsonError("usageType이 올바르지 않습니다.");

    if (isPrimary) {
      // 같은 usageType 내에서 대표(primary) 지정은 1개만 허용.
      await prisma.sectionAttachmentBinding.updateMany({
        where: { sectionId, usageType, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    const maxOrder = await prisma.sectionAttachmentBinding.aggregate({
      where: { sectionId, usageType },
      _max: { displayOrder: true },
    });

    const created = await prisma.sectionAttachmentBinding.create({
      data: {
        sectionId,
        attachmentUrl,
        usageType,
        isPrimary,
        displayOrder: (maxOrder._max.displayOrder ?? -1) + 1,
      },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId,
      actionType: "update",
      summary: `첨부파일 연결: ${section.sectionKey} - ${usageType}`,
    });

    return jsonOk(created, 201);
  } catch (e) {
    console.error("[POST .../attachments] 실패:", e);
    return jsonError("첨부파일 연결 중 오류가 발생했습니다.", 500);
  }
}
