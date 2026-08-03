// [메인화면 관리자 편집기] GET /api/admin/page-configs/home
// §14-1 대시보드: 현재 발행버전/임시저장버전/활성·숨김·예약 섹션 수/최근 수정자/최근 발행시각.
import { prisma } from "@/lib/db";
import { getOrCreatePageConfig, jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const config = await getOrCreatePageConfig(PAGE_KEY);

    const publishedVersion = config.currentPublishedVersionId
      ? await prisma.pageVersion.findUnique({ where: { id: config.currentPublishedVersionId } })
      : null;
    const draftVersion = config.currentDraftVersionId
      ? await prisma.pageVersion.findUnique({ where: { id: config.currentDraftVersionId } })
      : null;

    const draftSections = draftVersion
      ? await prisma.pageSection.findMany({
          where: { pageVersionId: draftVersion.id, deletedAt: null },
        })
      : [];

    const activeCount = draftSections.filter((s) => s.status === "visible").length;
    const hiddenCount = draftSections.filter((s) => s.status === "hidden").length;
    const archivedCount = draftSections.filter((s) => s.status === "archived").length;
    const scheduledCount = draftSections.filter((s) => s.scheduleEnabled).length;

    const lastAudit = await prisma.pageAuditLog.findFirst({
      where: { pageKey: PAGE_KEY },
      orderBy: { createdAt: "desc" },
    });

    return jsonOk({
      pageKey: PAGE_KEY,
      publishedVersion: publishedVersion
        ? {
            id: publishedVersion.id,
            versionNumber: publishedVersion.versionNumber,
            status: publishedVersion.status,
            publishedBy: publishedVersion.publishedBy,
            publishedAt: publishedVersion.publishedAt?.toISOString() ?? null,
          }
        : null,
      draftVersion: draftVersion
        ? {
            id: draftVersion.id,
            versionNumber: draftVersion.versionNumber,
            status: draftVersion.status,
            createdBy: draftVersion.createdBy,
            createdAt: draftVersion.createdAt.toISOString(),
          }
        : null,
      sectionCounts: {
        total: draftSections.length,
        active: activeCount,
        hidden: hiddenCount,
        archived: archivedCount,
        scheduled: scheduledCount,
      },
      lastEditor: lastAudit?.adminId ?? null,
      lastActionAt: lastAudit?.createdAt.toISOString() ?? null,
      lastActionType: lastAudit?.actionType ?? null,
    });
  } catch (e) {
    console.error("[GET /api/admin/page-configs/home] 실패:", e);
    return jsonError("대시보드 조회 중 오류가 발생했습니다.", 500);
  }
}
