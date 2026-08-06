import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import SubscriptionPlanCreateForm from "@/components/SubscriptionPlanCreateForm";
import SubscriptionPlanRow from "@/components/SubscriptionPlanRow";

// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 3차 소단위: 구독 플랜 관리 (K-3 subscription_plans)
// [범위 결정] 05§3.7: "구독 플랜 관리 | subscription_plans CRUD(가격/기간/혜택)".
//   §3.7에서 유일하게 완전 CRUD가 명시된 화면. RBAC_MATRIX.payments가 이미
//   {super_admin:RWD, operator:R, cs:R, content_manager:X}이므로 표준
//   canWriteMenu/canDeleteMenu(payments)를 그대로 사용(설계충돌 없음).
export const dynamic = "force-dynamic";

export default async function SubscriptionPlansPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "payments")) {
    redirect("/dashboard");
  }

  const canWrite = canWriteMenu(session.roleCode, "payments");
  const canDelete = canDeleteMenu(session.roleCode, "payments");

  const plans = await prisma.subscriptionPlan.findMany({
    orderBy: [{ isActive: "desc" }, { id: "asc" }],
  });

  const activeCount = plans.filter((p) => p.isActive).length;
  const inactiveCount = plans.length - activeCount;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">결제/구독 관리 — 구독 플랜 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          구독 플랜(가격/기간/혜택)을 생성, 수정, 삭제(비활성화)합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/payments/list" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            결제 내역
          </Link>
          <Link href="/payments/refunds" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            환불 처리
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">구독 플랜 관리</span>
          <Link href="/payments/subscriptions" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            구독 현황
          </Link>
          <Link href="/payments/revenue-report" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            매출 리포트
          </Link>
        </nav>
      </div>

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">전체 플랜</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{plans.length}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">활성 플랜</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activeCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">비활성 플랜</p>
          <p className="mt-1 text-2xl font-bold text-slate-500">{inactiveCount}</p>
        </div>
      </section>

      <SubscriptionPlanCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">플랜명</th>
              <th className="px-4 py-3">가격</th>
              <th className="px-4 py-3">기간</th>
              <th className="px-4 py-3">혜택</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {plans.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                  등록된 구독 플랜이 없습니다.
                </td>
              </tr>
            )}
            {plans.map((p) => (
              <SubscriptionPlanRow
                key={p.id}
                plan={{
                  id: p.id,
                  name: p.name,
                  price: p.price,
                  period: p.period,
                  benefits: JSON.parse(p.benefits) as string[],
                  isActive: p.isActive,
                }}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-4 text-xs text-slate-500">
        04A K-3 명시: period는 monthly/yearly입니다. 삭제 시 실제 레코드는 유지되며 isActive가 false로
        전환됩니다(soft delete).
      </p>
    </div>
  );
}
