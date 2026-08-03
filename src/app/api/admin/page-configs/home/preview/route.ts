// [메인화면 관리자 편집기] GET /admin/page-configs/home/preview
// §12/§14-4 미리보기: draft 버전을 그대로 렌더링 payload로 반환하고,
// 현재 발행(published) 버전과의 차이(diff)도 함께 계산해 "현재 운영 버전과 비교" 기능을 지원한다.
import { prisma } from "@/lib/db";
import { getOrCreateDraftVersion, getOrCreatePageConfig, jsonError, jsonOk, requireAdminOrResponse, isAdminActor, serializeSection } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET() {
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

    const publishedSections = config.currentPublishedVersionId
      ? await prisma.pageSection.findMany({
          where: { pageVersionId: config.currentPublishedVersionId, deletedAt: null },
          include: { attachments: true, displayRules: true },
          orderBy: { sortOrder: "asc" },
        })
      : [];

    const publishedByKey = new Map(publishedSections.map((s) => [s.sectionKey, s]));
    const draftKeys = new Set(draftSections.map((s) => s.sectionKey));

    type DiffEntry = { sectionKey: string; change: "added" | "modified" | "unchanged" | "removed" };
    const diff: DiffEntry[] = draftSections.map((s) => {
      const live = publishedByKey.get(s.sectionKey);
      if (!live) return { sectionKey: s.sectionKey, change: "added" as const };
      const changed =
        live.title !== s.title ||
        live.subtitle !== s.subtitle ||
        live.description !== s.description ||
        live.buttonText !== s.buttonText ||
        live.buttonLink !== s.buttonLink ||
        live.status !== s.status ||
        live.sortOrder !== s.sortOrder ||
        live.stylePreset !== s.stylePreset ||
        live.blockType !== s.blockType;
      return { sectionKey: s.sectionKey, change: changed ? ("modified" as const) : ("unchanged" as const) };
    });
    for (const live of publishedSections) {
      if (!draftKeys.has(live.sectionKey)) {
        diff.push({ sectionKey: live.sectionKey, change: "removed" as const });
      }
    }

    return jsonOk({
      draftVersion: { id: draft.id, versionNumber: draft.versionNumber },
      publishedVersionId: config.currentPublishedVersionId,
      sections: draftSections.map(serializeSection),
      diff,
    });
  } catch (e) {
    console.error("[GET /api/admin/page-configs/home/preview] 실패:", e);
    return jsonError("미리보기 조회 중 오류가 발생했습니다.", 500);
  }
}
