// [메인화면 관리자 편집기] GET /admin/page-configs/home/versions
// §14-8 변경 로그/버전 히스토리: page_versions 목록 + page_audit_logs 최근 이력.
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const versions = await prisma.pageVersion.findMany({
      where: { pageKey: PAGE_KEY },
      orderBy: { versionNumber: "desc" },
      include: { _count: { select: { sections: true } } },
    });

    const auditLogs = await prisma.pageAuditLog.findMany({
      where: { pageKey: PAGE_KEY },
      orderBy: { createdAt: "desc" },
      take: 100,
    });

    return jsonOk({
      versions: versions.map((v) => ({
        id: v.id,
        versionNumber: v.versionNumber,
        status: v.status,
        createdBy: v.createdBy,
        publishedBy: v.publishedBy,
        createdAt: v.createdAt.toISOString(),
        publishedAt: v.publishedAt?.toISOString() ?? null,
        sectionCount: v._count.sections,
      })),
      auditLogs: auditLogs.map((a) => ({
        id: a.id,
        adminId: a.adminId,
        sectionId: a.sectionId,
        actionType: a.actionType,
        summary: a.summary,
        createdAt: a.createdAt.toISOString(),
      })),
    });
  } catch (e) {
    console.error("[GET /api/admin/page-configs/home/versions] 실패:", e);
    return jsonError("버전 히스토리 조회 중 오류가 발생했습니다.", 500);
  }
}
