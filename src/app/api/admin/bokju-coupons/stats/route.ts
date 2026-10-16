// [복주머니 마케팅 쿠폰 최종본 §8] GET /api/admin/bokju-coupons/stats
// 전체 캠페인 통계 요약 — 캠페인별 발행/배정/등록/전환율 및 업체별 실적.
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";

export const dynamic = "force-dynamic";

export async function GET() {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  try {
    const campaigns = await prisma.bokjuCouponCampaign.findMany({
      orderBy: { createdAt: "desc" },
    });

    const campaignStats = campaigns.map((c) => ({
      campaignId: c.id,
      title: c.title,
      status: c.status,
      issuedCount: c.issuedCount,
      allocatedCount: c.allocatedCount,
      redeemedCount: c.redeemedCount,
      conversionRate: c.issuedCount ? +((c.redeemedCount / c.issuedCount) * 100).toFixed(1) : 0,
      createdAt: c.createdAt.toISOString(),
    }));

    // 업체별 실적(전체 캠페인 합산)
    const partners = await prisma.bokjuPartner.findMany({
      include: { allocations: { include: { reports: true } } },
    });
    const partnerStats = await Promise.all(
      partners.map(async (p) => {
        const allocatedQty = p.allocations.reduce((sum, a) => sum + a.allocatedQty, 0);
        const reportedQty = p.allocations.reduce(
          (sum, a) => sum + a.reports.reduce((s, r) => s + r.reportedQty, 0),
          0
        );
        const redeemedQty = await prisma.bokjuCoupon.count({
          where: { partnerId: p.id, status: "REDEEMED" },
        });
        return {
          partnerId: p.id,
          partnerName: p.name,
          allocatedQty,
          reportedQty,
          redeemedQty,
          redemptionRate: allocatedQty ? +((redeemedQty / allocatedQty) * 100).toFixed(1) : 0,
        };
      })
    );

    const totals = {
      totalCampaigns: campaigns.length,
      totalIssued: campaigns.reduce((s, c) => s + c.issuedCount, 0),
      totalAllocated: campaigns.reduce((s, c) => s + c.allocatedCount, 0),
      totalRedeemed: campaigns.reduce((s, c) => s + c.redeemedCount, 0),
    };

    return jsonOk({ totals, campaigns: campaignStats, partners: partnerStats, measuredAt: new Date().toISOString() });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/stats] 실패:", e);
    return jsonError("통계 조회 중 오류가 발생했습니다.", 500);
  }
}
