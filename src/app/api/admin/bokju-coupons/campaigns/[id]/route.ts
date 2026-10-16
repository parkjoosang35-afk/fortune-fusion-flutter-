// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/campaigns/:id
// 캠페인 상세 + 쿠폰 상태별 집계.
// DELETE /api/admin/bokju-coupons/campaigns/:id — 캠페인 전체 삭제(§쿠폰 삭제 기능).
import { prisma } from "@/lib/db";
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { deleteCampaign, BokjuCouponError } from "@/lib/bokju-coupon-service";
import { writeCouponAuditLog } from "@/lib/bokju-coupon-audit";

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
    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

    const statusGroups = await prisma.bokjuCoupon.groupBy({
      by: ["status"],
      where: { campaignId },
      _count: { _all: true },
    });

    const latestImageJob = await prisma.bokjuCouponImageJob.findFirst({
      where: { campaignId },
      orderBy: { createdAt: "desc" },
    });

    return jsonOk({
      campaign: {
        id: campaign.id,
        title: campaign.title,
        grantAmount: campaign.grantAmount,
        issueType: campaign.issueType,
        targetAudience: campaign.targetAudience,
        useLimitPerMember: campaign.useLimitPerMember,
        sharedTotalLimit: campaign.sharedTotalLimit,
        distributionMethod: campaign.distributionMethod,
        designTemplate: campaign.designTemplate,
        status: campaign.status,
        validFrom: campaign.validFrom.toISOString(),
        validTo: campaign.validTo.toISOString(),
        guideText: campaign.guideText,
        issuedCount: campaign.issuedCount,
        allocatedCount: campaign.allocatedCount,
        redeemedCount: campaign.redeemedCount,
        usedCount: campaign.usedCount,
        createdAt: campaign.createdAt.toISOString(),
      },
      statusCounts: Object.fromEntries(statusGroups.map((g) => [g.status, g._count._all])),
      latestImageJob: latestImageJob
        ? {
            id: latestImageJob.id,
            status: latestImageJob.status,
            totalCount: latestImageJob.totalCount,
            processedCount: latestImageJob.processedCount,
            failedCount: latestImageJob.failedCount,
            zipPath: latestImageJob.zipPath,
            excelPath: latestImageJob.excelPath,
            createdAt: latestImageJob.createdAt.toISOString(),
          }
        : null,
    });
  } catch (e) {
    console.error("[GET /api/admin/bokju-coupons/campaigns/:id] 실패:", e);
    return jsonError("캠페인 조회 중 오류가 발생했습니다.", 500);
  }
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const result = await deleteCampaign(campaignId);
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId: result.campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "DELETE",
      summary: `캠페인 삭제: ${result.title} (쿠폰 ${result.deletedCoupons}장 포함)`,
    });
    return jsonOk(result);
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[DELETE /api/admin/bokju-coupons/campaigns/:id] 실패:", e);
    return jsonError("캠페인 삭제 중 오류가 발생했습니다.", 500);
  }
}
