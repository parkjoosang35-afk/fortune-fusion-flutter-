import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuPartnerCreateForm from "@/components/BokjuPartnerCreateForm";
import BokjuPartnerRow from "@/components/BokjuPartnerRow";

export const dynamic = "force-dynamic";

export default async function BokjuPartnersPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  const partners = await prisma.bokjuPartner.findMany({
    orderBy: { createdAt: "desc" },
    include: { accounts: { select: { id: true, loginId: true, role: true, status: true, lastLoginAt: true } } },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 제휴업체 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          제휴업체를 등록하고 전용 로그인 계정을 발급합니다. 업체는 발급받은 계정으로
          업체 전용 화면에 접속해 배정받은 쿠폰 배포 현황을 확인/보고할 수 있습니다.
        </p>
      </div>

      <BokjuCouponSubNav />

      <BokjuPartnerCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">업체명</th>
              <th className="px-4 py-3">담당자</th>
              <th className="px-4 py-3">연락처</th>
              <th className="px-4 py-3">로그인 계정</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {partners.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                  등록된 제휴업체가 없습니다.
                </td>
              </tr>
            )}
            {partners.map((p) => (
              <BokjuPartnerRow
                key={p.id}
                partner={{
                  id: p.id,
                  name: p.name,
                  managerName: p.managerName,
                  managerContact: p.managerContact,
                  status: p.status,
                  accounts: p.accounts.map((a) => ({
                    id: a.id,
                    loginId: a.loginId,
                    role: a.role,
                    status: a.status,
                    lastLoginAt: a.lastLoginAt ? a.lastLoginAt.toISOString() : null,
                  })),
                }}
                canWrite={canWrite}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
