// [메인화면 관리자 편집기] GET /admin/page-configs/home/draft
// §14-2 섹션 리스트 화면이 사용할 draft 버전의 전체 섹션(첨부/노출조건 포함) 조회.
import { prisma } from "@/lib/db";
import {
  getOrCreateDraftVersion,
  jsonError,
  jsonOk,
  requireAdminOrResponse,
  isAdminActor,
  serializeSection,
} from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const draft = await getOrCreateDraftVersion(PAGE_KEY);
    const sections = await prisma.pageSection.findMany({
      where: { pageVersionId: draft.id, deletedAt: null },
      include: { attachments: { orderBy: { displayOrder: "asc" } }, displayRules: true },
      orderBy: { sortOrder: "asc" },
    });

    return jsonOk({
      version: {
        id: draft.id,
        versionNumber: draft.versionNumber,
        status: draft.status,
        createdBy: draft.createdBy,
        createdAt: draft.createdAt.toISOString(),
      },
      sections: sections.map(serializeSection),
    });
  } catch (e) {
    console.error("[GET /api/admin/page-configs/home/draft] 실패:", e);
    return jsonError("draft 조회 중 오류가 발생했습니다.", 500);
  }
}
