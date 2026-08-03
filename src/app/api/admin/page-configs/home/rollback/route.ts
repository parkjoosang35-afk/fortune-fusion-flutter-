// [메인화면 관리자 편집기] POST /admin/page-configs/home/rollback
// §12 롤백 — append-only 구조이므로 과거 published 버전의 PageSection 행이 그대로
// 보관되어 있다. 따라서 롤백은 "복사/재생성" 없이 PageConfig.currentPublishedVersionId
// 포인터를 목표 버전으로 되돌리는 것만으로 즉시 완료된다.
// body: { targetVersionNumber: number }
import { prisma } from "@/lib/db";
import { getOrCreatePageConfig, isAdminActor, jsonError, jsonOk, requireAdminOrResponse, writeAuditLog } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function POST(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const body = await request.json();
    const targetVersionNumber = Number(body.targetVersionNumber);
    if (!Number.isInteger(targetVersionNumber)) {
      return jsonError("targetVersionNumber가 올바르지 않습니다.");
    }

    const target = await prisma.pageVersion.findUnique({
      where: { pageKey_versionNumber: { pageKey: PAGE_KEY, versionNumber: targetVersionNumber } },
    });
    if (!target || target.status !== "published") {
      return jsonError("롤백 대상은 과거에 발행(published)된 버전이어야 합니다.");
    }

    const config = await getOrCreatePageConfig(PAGE_KEY);
    if (config.currentPublishedVersionId === target.id) {
      return jsonError("이미 현재 발행 버전입니다.");
    }

    const previousVersionId = config.currentPublishedVersionId;

    await prisma.pageConfig.update({
      where: { id: config.id },
      data: { currentPublishedVersionId: target.id },
    });

    await writeAuditLog({
      adminId: actor.adminId,
      pageKey: PAGE_KEY,
      actionType: "rollback",
      summary: `v${targetVersionNumber}으로 롤백`,
      payload: { fromVersionId: previousVersionId, toVersionId: target.id, toVersionNumber: targetVersionNumber },
    });

    return jsonOk({ publishedVersionId: target.id, publishedVersionNumber: target.versionNumber });
  } catch (e) {
    console.error("[POST /api/admin/page-configs/home/rollback] 실패:", e);
    return jsonError("롤백 중 오류가 발생했습니다.", 500);
  }
}
