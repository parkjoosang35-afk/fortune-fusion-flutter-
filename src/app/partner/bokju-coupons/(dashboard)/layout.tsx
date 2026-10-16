import { redirect } from "next/navigation";
import { getPartnerSession } from "@/lib/partner-session";
import PartnerLogoutButton from "@/components/PartnerLogoutButton";

// [복주머니 마케팅 쿠폰] 업체 전용 대시보드 레이아웃.
// admin (admin)/layout.tsx와 완전히 분리된 세션(bokju_partner_session)으로 가드한다.
export default async function PartnerDashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await getPartnerSession();
  if (!session) {
    redirect("/partner/bokju-coupons/login");
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="flex items-center justify-between border-b border-slate-200 bg-white px-6 py-4">
        <div>
          <p className="text-sm font-bold text-slate-900">신통방통 제휴업체 센터</p>
          <p className="text-xs text-slate-500">
            {session.loginId} ({session.role === "PARTNER_ADMIN" ? "업체 관리자" : "업체 직원"})
          </p>
        </div>
        <PartnerLogoutButton />
      </header>
      <main className="mx-auto max-w-4xl p-6">{children}</main>
    </div>
  );
}
