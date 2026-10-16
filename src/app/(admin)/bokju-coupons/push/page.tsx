import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuPushSendForm from "@/components/BokjuPushSendForm";

// [복주머니 마케팅 쿠폰 최종본 §10 "기존 회원 푸시 알림"] "회원 푸시 발송" 메뉴.
// 발행된 ACTIVE 캠페인을 골라 전체 이벤트 안내(BROADCAST) 또는 개별 회원
// 선물(INDIVIDUAL)을 발송하고, 과거 발송 이력(성공/실패 집계)을 함께 보여준다.
export const dynamic = "force-dynamic";

export default async function BokjuPushPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  const campaigns = await prisma.bokjuCouponCampaign.findMany({
    where: { status: { in: ["ACTIVE", "PAUSED"] } },
    select: { id: true, title: true, status: true, issuedCount: true },
    orderBy: { createdAt: "desc" },
  });

  // BokjuCouponPushJob은 campaignId를 FK 관계가 아닌 단순 컬럼으로만 보유하므로
  // (스키마에 relation 필드 없음) include를 쓸 수 없다 — 캠페인 제목은 별도 조회 후
  // 메모리에서 매핑한다.
  const pushJobs = await prisma.bokjuCouponPushJob.findMany({
    orderBy: { createdAt: "desc" },
    take: 30,
  });
  const jobCampaignIds = Array.from(new Set(pushJobs.map((j) => j.campaignId)));
  const jobCampaigns = jobCampaignIds.length
    ? await prisma.bokjuCouponCampaign.findMany({
        where: { id: { in: jobCampaignIds } },
        select: { id: true, title: true },
      })
    : [];
  const campaignTitleById = new Map(jobCampaigns.map((c) => [c.id, c.title]));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 회원 푸시 발송</h1>
        <p className="mt-1 text-sm text-slate-500">
          기존 신통방통 회원에게 쿠폰 이벤트를 알립니다. 전체 이벤트 안내는 조건에 맞는 회원 모두에게,
          개별 선물은 지정한 회원에게 쿠폰을 먼저 배정한 뒤 알림을 보냅니다(발송 실패해도 배정은
          유지됩니다).
        </p>
      </div>

      <BokjuCouponSubNav />

      <BokjuPushSendForm
        campaigns={campaigns}
        canWrite={canWrite}
      />

      <div className="mt-8">
        <h2 className="mb-3 text-sm font-bold text-slate-900">발송 이력</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">캠페인</th>
                <th className="px-4 py-3">방식</th>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">성공/실패</th>
                <th className="px-4 py-3">생성일시</th>
              </tr>
            </thead>
            <tbody>
              {pushJobs.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                    발송 이력이 없습니다.
                  </td>
                </tr>
              )}
              {pushJobs.map((j) => (
                <tr key={j.id} className="border-b border-slate-100">
                  <td className="px-4 py-2 font-medium text-slate-900">
                    {campaignTitleById.get(j.campaignId) ?? `#${j.campaignId}`}
                  </td>
                  <td className="px-4 py-2">{j.sendMode === "INDIVIDUAL" ? "개별 선물" : "전체 이벤트"}</td>
                  <td className="px-4 py-2">{j.targetFilter}</td>
                  <td className="px-4 py-2">{j.title}</td>
                  <td className="px-4 py-2">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        j.status === "COMPLETED"
                          ? "bg-emerald-100 text-emerald-700"
                          : j.status === "PARTIAL"
                          ? "bg-amber-100 text-amber-700"
                          : j.status === "FAILED"
                          ? "bg-rose-100 text-rose-700"
                          : "bg-slate-100 text-slate-600"
                      }`}
                    >
                      {j.status}
                    </span>
                  </td>
                  <td className="px-4 py-2">
                    <span className="text-emerald-700">{j.successCount}</span>
                    {" / "}
                    <span className="text-rose-700">{j.failCount}</span>
                  </td>
                  <td className="px-4 py-2 text-xs text-slate-500">
                    {j.createdAt.toISOString().slice(0, 16).replace("T", " ")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
