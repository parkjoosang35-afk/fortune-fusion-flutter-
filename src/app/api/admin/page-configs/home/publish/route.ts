// [메인화면 관리자 편집기] POST /admin/page-configs/home/publish
// §12 발행 — draft → 새 published PageVersion으로 스냅샷 복제하고,
// PageConfig.currentPublishedVersionId 포인터만 옮긴다(append-only, 과거 published
// 버전의 PageSection 행은 삭제하지 않고 그대로 보관 -> 즉시 롤백 가능).
// 발행 후에는 이어서 편집할 수 있도록 방금 발행한 내용을 복제한 "새 draft"를 자동 생성한다.
import { prisma } from "@/lib/db";
import {
  cloneSectionIntoVersion,
  getOrCreateDraftVersion,
  getOrCreatePageConfig,
  isAdminActor,
  jsonError,
  jsonOk,
  requireAdminOrResponse,
  writeAuditLog,
} from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function POST() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const config = await getOrCreatePageConfig(PAGE_KEY);
    const draft = await getOrCreateDraftVersion(PAGE_KEY);

    const draftSections = await prisma.pageSection.findMany({
      where: { pageVersionId: draft.id, deletedAt: null },
      include: { attachments: true, displayRules: true },
      orderBy: { sortOrder: "asc" },
    });

    if (draftSections.length === 0) {
      return jsonError("draft에 발행할 섹션이 없습니다.");
    }

    const latestVersionNumber = await prisma.pageVersion.aggregate({
      where: { pageKey: PAGE_KEY },
      _max: { versionNumber: true },
    });
    const publishedVersionNumber = (latestVersionNumber._max.versionNumber ?? 0) + 1;

    const publishedVersion = await prisma.pageVersion.create({
      data: {
        pageKey: PAGE_KEY,
        versionNumber: publishedVersionNumber,
        status: "published",
        createdBy: actor.adminId,
        publishedBy: actor.adminId,
        publishedAt: new Date(),
      },
    });

    for (const s of draftSections) {
      await cloneSectionIntoVersion(s, publishedVersion.id);
    }

    // 발행 직후에도 계속 편집할 수 있도록, 방금 발행한 스냅샷을 복제해 새 draft로 둔다.
    const nextDraftVersion = await prisma.pageVersion.create({
      data: { pageKey: PAGE_KEY, versionNumber: publishedVersionNumber + 1, status: "draft", createdBy: actor.adminId },
    });
    for (const s of draftSections) {
      await cloneSectionIntoVersion(s, nextDraftVersion.id);
    }

    await prisma.pageConfig.update({
      where: { id: config.id },
      data: { currentPublishedVersionId: publishedVersion.id, currentDraftVersionId: nextDraftVersion.id },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      actionType: "publish",
      summary: `v${publishedVersionNumber} 발행 완료 (섹션 ${draftSections.length}개)`,
      payload: { publishedVersionId: publishedVersion.id, sectionCount: draftSections.length },
    });

    return jsonOk({
      publishedVersion: {
        id: publishedVersion.id,
        versionNumber: publishedVersion.versionNumber,
        publishedAt: publishedVersion.publishedAt?.toISOString() ?? null,
      },
      newDraftVersionId: nextDraftVersion.id,
    });
  } catch (e) {
    console.error("[POST /api/admin/page-configs/home/publish] 실패:", e);
    return jsonError("발행 중 오류가 발생했습니다.", 500);
  }
}
