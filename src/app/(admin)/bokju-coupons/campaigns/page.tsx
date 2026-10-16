import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuCampaignCreateForm from "@/components/BokjuCampaignCreateForm";
import BokjuCampaignRow from "@/components/BokjuCampaignRow";

// [복주머니 마케팅 쿠폰 최종본 §3] "쿠폰 만들기" + "발행 쿠폰 관리" 진입점.
// 목록에서 새 캠페인을 만들고, 각 행을 클릭하면 상세(발행/배정/이미지생성)로 이동.
export const dynamic = "force-dynamic";

export default async function BokjuCampaignsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  const campaigns = await prisma.bokjuCouponCampaign.findMany({
    orderBy: { createdAt: "desc" },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 쿠폰 만들기 / 발행 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          제휴업체 QR 쿠폰을 통해 복주머니를 지급하는 마케팅 캠페인을 관리합니다. 캠페인 생성 →
          쿠폰 발행 → 업체 배정/직접 배포 → 회원 등록(복주머니 적립) 순서로 진행합니다.
        </p>
      </div>

      <BokjuCouponSubNav />

      <BokjuCampaignCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">캠페인명</th>
              <th className="px-4 py-3">지급액</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">발행</th>
              <th className="px-4 py-3">배정</th>
              <th className="px-4 py-3">등록(적립)</th>
              <th className="px-4 py-3">사용기간</th>
            </tr>
          </thead>
          <tbody>
            {campaigns.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-slate-500">
                  등록된 쿠폰 캠페인이 없습니다. 위 버튼으로 새 캠페인을 만들어보세요.
                </td>
              </tr>
            )}
            {campaigns.map((c) => (
              <BokjuCampaignRow
                key={c.id}
                campaign={{
                  id: c.id,
                  title: c.title,
                  grantAmount: c.grantAmount,
                  issueType: c.issueType,
                  status: c.status,
                  issuedCount: c.issuedCount,
                  allocatedCount: c.allocatedCount,
                  redeemedCount: c.redeemedCount,
                  validFrom: c.validFrom.toISOString(),
                  validTo: c.validTo.toISOString(),
                }}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
