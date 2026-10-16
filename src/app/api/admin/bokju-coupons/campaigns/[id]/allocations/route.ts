// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/campaigns/:id/allocations
// 캠페인 기준 업체별 배정/전달/보고/등록 현황판 — §8 "업체별 배포 및 사용 현황판".
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const allocations = await prisma.bokjuCouponAllocation.findMany({
      where: { campaignId },
      include: { partner: true, reports: true },
      orderBy: { createdAt: "desc" },
    });

    const data = await Promise.all(
      allocations.map(async (a) => {
        const redeemedQty = await prisma.bokjuCoupon.count({
          where: { allocationId: a.id, status: "REDEEMED" },
        });
        const reportedQty = a.reports.reduce((sum, r) => sum + r.reportedQty, 0);
        return {
          allocationId: a.id,
          partnerId: a.partnerId,
          partnerName: a.partner.name,
          allocatedQty: a.allocatedQty,
          deliveredAt: a.deliveredAt ? a.deliveredAt.toISOString() : null,
          acknowledgedAt: a.acknowledgedAt ? a.acknowledgedAt.toISOString() : null,
          distributeDeadline: a.distributeDeadline ? a.distributeDeadline.toISOString() : null,
          recalledQty: a.recalledQty,
          status: a.status,
          reportedQty, // ★ 업체 자체 보고
          redeemedQty, // ★ 시스템 확인(절대 혼동 금지)
          redemptionRate: a.allocatedQty ? +((redeemedQty / a.allocatedQty) * 100).toFixed(1) : 0,
          createdAt: a.createdAt.toISOString(),
        };
      })
    );

    return jsonOk({ allocations: data });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/campaigns/:id/allocations] 실패:", e);
    return jsonError("배정 현황 조회 중 오류가 발생했습니다.", 500);
  }
}
