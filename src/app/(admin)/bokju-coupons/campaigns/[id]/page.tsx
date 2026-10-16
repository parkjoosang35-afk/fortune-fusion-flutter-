import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuCampaignDetailClient from "@/components/BokjuCampaignDetailClient";

export const dynamic = "force-dynamic";

export default async function BokjuCampaignDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) notFound();

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
  if (!campaign) notFound();

  const [statusGroups, latestImageJob, partners, allocationsRaw, recalledAvailable] = await Promise.all([
    prisma.bokjuCoupon.groupBy({ by: ["status"], where: { campaignId }, _count: { _all: true } }),
    prisma.bokjuCouponImageJob.findFirst({ where: { campaignId }, orderBy: { createdAt: "desc" } }),
    prisma.bokjuPartner.findMany({ where: { status: "ACTIVE" }, orderBy: { name: "asc" } }),
    prisma.bokjuCouponAllocation.findMany({
      where: { campaignId },
      include: { partner: true, reports: true },
      orderBy: { createdAt: "desc" },
    }),
    // [§9/§22.6 재배정] RECALLED + 미사용 + 미배정만 재배정 가능 수량으로 집계
    prisma.bokjuCoupon.count({
      where: { campaignId, status: "RECALLED", redeemedAt: null, assignedUserId: null },
    }),
  ]);

  const allocations = await Promise.all(
    allocationsRaw.map(async (a) => {
      const redeemedQty = await prisma.bokjuCoupon.count({ where: { allocationId: a.id, status: "REDEEMED" } });
      const reportedQty = a.reports.reduce((sum, r) => sum + r.reportedQty, 0);
      return {
        allocationId: a.id,
        partnerId: a.partnerId,
        partnerName: a.partner.name,
        allocatedQty: a.allocatedQty,
        deliveredAt: a.deliveredAt ? a.deliveredAt.toISOString() : null,
        recalledQty: a.recalledQty,
        status: a.status,
        reportedQty,
        redeemedQty,
        redemptionRate: a.allocatedQty ? +((redeemedQty / a.allocatedQty) * 100).toFixed(1) : 0,
      };
    })
  );

  return (
    <div>
      <div className="mb-6">
        <Link href="/bokju-coupons/campaigns" className="text-sm text-indigo-600 hover:underline">
          ← 캠페인 목록
        </Link>
        <h1 className="mt-1 text-2xl font-bold text-slate-900">캠페인 상세</h1>
      </div>

      <BokjuCouponSubNav />

      <BokjuCampaignDetailClient
        campaign={{
          id: campaign.id,
          title: campaign.title,
          grantAmount: campaign.grantAmount,
          issueType: campaign.issueType,
          targetAudience: campaign.targetAudience,
          useLimitPerMember: campaign.useLimitPerMember,
          sharedTotalLimit: campaign.sharedTotalLimit,
          distributionMethod: campaign.distributionMethod,
          status: campaign.status,
          validFrom: campaign.validFrom.toISOString(),
          validTo: campaign.validTo.toISOString(),
          guideText: campaign.guideText,
          issuedCount: campaign.issuedCount,
          allocatedCount: campaign.allocatedCount,
          redeemedCount: campaign.redeemedCount,
          usedCount: campaign.usedCount,
        }}
        statusCounts={Object.fromEntries(statusGroups.map((g) => [g.status, g._count._all]))}
        latestImageJob={
          latestImageJob
            ? {
                id: latestImageJob.id,
                status: latestImageJob.status,
                totalCount: latestImageJob.totalCount,
                processedCount: latestImageJob.processedCount,
                failedCount: latestImageJob.failedCount,
                zipPath: latestImageJob.zipPath,
                excelPath: latestImageJob.excelPath,
              }
            : null
        }
        partners={partners.map((p) => ({ id: p.id, name: p.name }))}
        allocations={allocations}
        recalledAvailable={recalledAvailable}
        canWrite={canWrite}
      />
    </div>
  );
}
