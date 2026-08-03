// [메인화면 관리자 편집기] POST /admin/page-configs/home/sections
// §3 "섹션 추가" — draft 버전에 새 섹션을 blockType 화이트리스트 안에서만 생성.
import { prisma } from "@/lib/db";
import { isValidBlockType } from "@/lib/page-config-constants";
import {
  getOrCreateDraftVersion,
  isAdminActor,
  jsonError,
  jsonOk,
  requireAdminOrResponse,
  serializeSection,
  writeAuditLog,
} from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const sectionKey = typeof body.sectionKey === "string" ? body.sectionKey.trim() : "";
    const blockType = typeof body.blockType === "string" ? body.blockType : "";
    const title = typeof body.title === "string" ? body.title : null;

    if (!sectionKey) return jsonError("sectionKey는 필수입니다.");
    if (!isValidBlockType(blockType)) {
      return jsonError("blockType은 지원되는 블록 타입 중에서만 선택할 수 있습니다.");
    }

    const draft = await getOrCreateDraftVersion(PAGE_KEY);

    const duplicateKey = await prisma.pageSection.findFirst({
      where: { pageVersionId: draft.id, sectionKey, deletedAt: null },
    });
    if (duplicateKey) {
      return jsonError("동일한 sectionKey가 이미 draft 버전에 존재합니다.");
    }

    const maxOrder = await prisma.pageSection.aggregate({
      where: { pageVersionId: draft.id, deletedAt: null },
      _max: { sortOrder: true },
    });

    const created = await prisma.pageSection.create({
      data: {
        pageVersionId: draft.id,
        sectionKey,
        blockType,
        title,
        stylePreset: "default",
        backgroundPreset: "white",
        alignmentPreset: "left",
        densityPreset: "normal",
        sortOrder: (maxOrder._max.sortOrder ?? -1) + 1,
        createdBy: actor.adminId,
        updatedBy: actor.adminId,
      },
      include: { attachments: true, displayRules: true },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      sectionId: created.id,
      actionType: "create",
      summary: `섹션 생성: ${sectionKey} (${blockType})`,
    });

    return jsonOk(serializeSection(created), 201);
  } catch (e) {
    console.error("[POST /api/admin/page-configs/home/sections] 실패:", e);
    return jsonError("섹션 생성 중 오류가 발생했습니다.", 500);
  }
}
