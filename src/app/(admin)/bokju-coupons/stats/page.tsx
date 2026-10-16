import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";

export const dynamic = "force-dynamic";

export default async function BokjuStatsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }

  const campaigns = await prisma.bokjuCouponCampaign.findMany({ orderBy: { createdAt: "desc" } });
  const campaignStats = campaigns.map((c) => ({
    campaignId: c.id,
    title: c.title,
    status: c.status,
    issuedCount: c.issuedCount,
    allocatedCount: c.allocatedCount,
    redeemedCount: c.redeemedCount,
    conversionRate: c.issuedCount ? +((c.redeemedCount / c.issuedCount) * 100).toFixed(1) : 0,
  }));

  const partners = await prisma.bokjuPartner.findMany({ include: { allocations: { include: { reports: true } } } });
  const partnerStats = await Promise.all(
    partners.map(async (p) => {
      const allocatedQty = p.allocations.reduce((sum, a) => sum + a.allocatedQty, 0);
      const reportedQty = p.allocations.reduce((sum, a) => sum + a.reports.reduce((s, r) => s + r.reportedQty, 0), 0);
      const redeemedQty = await prisma.bokjuCoupon.count({ where: { partnerId: p.id, status: "REDEEMED" } });
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

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 쿠폰 통계</h1>
        <p className="mt-1 text-sm text-slate-500">
          캠페인별 발행/배정/등록 현황과 업체별 실적을 확인합니다. 측정 시각: {new Date().toLocaleString("ko-KR")}
        </p>
      </div>

      <BokjuCouponSubNav />

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">총 캠페인</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totals.totalCampaigns}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">총 발행</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totals.totalIssued}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">총 배정</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totals.totalAllocated}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">총 등록(적립)</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{totals.totalRedeemed}</p>
        </div>
      </div>

      <h2 className="mb-2 text-sm font-bold text-slate-900">캠페인별 통계</h2>
      <div className="mb-6 overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">캠페인</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">발행</th>
              <th className="px-4 py-3">배정</th>
              <th className="px-4 py-3">등록</th>
              <th className="px-4 py-3">전환율</th>
            </tr>
          </thead>
          <tbody>
            {campaignStats.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  캠페인이 없습니다.
                </td>
              </tr>
            )}
            {campaignStats.map((c) => (
              <tr key={c.campaignId} className="border-b border-slate-100">
                <td className="px-4 py-3 font-medium text-slate-900">{c.title}</td>
                <td className="px-4 py-3">{c.status}</td>
                <td className="px-4 py-3">{c.issuedCount}</td>
                <td className="px-4 py-3">{c.allocatedCount}</td>
                <td className="px-4 py-3">{c.redeemedCount}</td>
                <td className="px-4 py-3">{c.conversionRate}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2 className="mb-2 text-sm font-bold text-slate-900">업체별 실적(전체 캠페인 합산)</h2>
      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">업체</th>
              <th className="px-4 py-3">배정</th>
              <th className="px-4 py-3">업체보고</th>
              <th className="px-4 py-3">시스템등록</th>
              <th className="px-4 py-3">전환율</th>
            </tr>
          </thead>
          <tbody>
            {partnerStats.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                  제휴업체가 없습니다.
                </td>
              </tr>
            )}
            {partnerStats.map((p) => (
              <tr key={p.partnerId} className="border-b border-slate-100">
                <td className="px-4 py-3 font-medium text-slate-900">{p.partnerName}</td>
                <td className="px-4 py-3">{p.allocatedQty}</td>
                <td className="px-4 py-3">{p.reportedQty}</td>
                <td className="px-4 py-3 font-semibold text-emerald-700">{p.redeemedQty}</td>
                <td className="px-4 py-3">{p.redemptionRate}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-400">
        * &quot;업체보고&quot;는 업체가 직접 제출한 수치이며, &quot;시스템등록&quot;은 실제 QR 등록(복주머니 적립) 완료 건수입니다. 두 수치는 절대 합산하지 않습니다.
      </p>
    </div>
  );
}
