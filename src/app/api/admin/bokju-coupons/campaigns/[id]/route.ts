// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/campaigns/:id
// 캠페인 상세 + 쿠폰 상태별 집계.
// PATCH /api/admin/bokju-coupons/campaigns/:id — [마케팅 쿠폰 발행 관리 개선 §5-4]
// 발행 한도(totalIssueLimit)만 변경 가능. 기존 발급 수량(issuedCount)보다
// 작은 값으로는 축소할 수 없도록 서버에서 검증한다(화면에서만 막지 않고
// 실제 저장 단계에서 차단 — §6 "화면에만 추가하고 서버 검증 누락 금지").
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
        totalIssueLimit: campaign.totalIssueLimit,
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

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  try {
    const body = await request.json();
    if (!("totalIssueLimit" in body)) {
      return jsonError("totalIssueLimit 필드가 필요합니다.");
    }

    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

    let totalIssueLimit: number | null;
    if (body.totalIssueLimit === null || body.totalIssueLimit === "") {
      totalIssueLimit = null; // 무제한으로 전환 — 이미 발급된 수량과 무관하게 항상 허용
    } else {
      const n = Number(body.totalIssueLimit);
      if (!Number.isInteger(n) || n < 1) {
        return jsonError("totalIssueLimit은 1 이상의 정수이거나 무제한(null)이어야 합니다.");
      }
      // [§5-4] 발행 수량을 기존 발급 수량보다 적게 변경하지 못하도록 차단.
      if (n < campaign.issuedCount) {
        return jsonError(
          `총 발행 한도는 이미 발급된 수량(${campaign.issuedCount}장)보다 작게 설정할 수 없습니다.`
        );
      }
      totalIssueLimit = n;
    }

    const updated = await prisma.bokjuCouponCampaign.update({
      where: { id: campaignId },
      data: { totalIssueLimit },
    });
    await writeCouponAuditLog({
      actorId: actor.adminId,
      campaignId,
      targetType: "CAMPAIGN",
      targetId: campaignId,
      actionType: "UPDATE_ISSUE_LIMIT",
      summary: `총 발행 한도 변경: ${campaign.totalIssueLimit ?? "무제한"} → ${updated.totalIssueLimit ?? "무제한"}`,
    });
    return jsonOk({ id: updated.id, totalIssueLimit: updated.totalIssueLimit });
  } catch (e) {
    if (e instanceof BokjuCouponError) return jsonError(e.message, 400);
    console.error("[PATCH /api/admin/bokju-coupons/campaigns/:id] 실패:", e);
    return jsonError("캠페인 수정 중 오류가 발생했습니다.", 500);
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
