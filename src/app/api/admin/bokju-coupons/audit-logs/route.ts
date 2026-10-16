// [복주머니 마케팅 쿠폰 최종본 §12] GET /api/admin/bokju-coupons/audit-logs
// 감사 로그 조회 — ?campaignId=로 필터링 가능.
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const url = new URL(request.url);
  const campaignId = url.searchParams.get("campaignId");

  try {
    const logs = await prisma.bokjuCouponAuditLog.findMany({
      where: campaignId ? { campaignId: Number(campaignId) } : undefined,
      orderBy: { createdAt: "desc" },
      take: 200,
    });

    return jsonOk({
      logs: logs.map((l) => ({
        id: l.id,
        actorId: l.actorId,
        actorType: l.actorType,
        campaignId: l.campaignId,
        targetType: l.targetType,
        targetId: l.targetId,
        actionType: l.actionType,
        summary: l.summary,
        createdAt: l.createdAt.toISOString(),
      })),
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/audit-logs] 실패:", e);
    return jsonError("감사 로그 조회 중 오류가 발생했습니다.", 500);
  }
}
