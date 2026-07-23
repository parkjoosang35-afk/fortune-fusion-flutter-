import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import SubscriptionRow from "@/components/SubscriptionRow";

// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 4차 소단위: 구독 현황 조회 (K-4 user_subscriptions)
// [범위 결정] 05§3.7: "구독 현황 조회 | user_subscriptions 조회, 강제 해지(사유 필수)".
//   K-3(완전CRUD)와 달리 이 화면은 조회 + 제한적 write 1건(강제해지)만 명시됨.
// [RBAC] RBAC_MATRIX.payments={super_admin:RWD, operator:R, cs:R, content_manager:X}.
//   강제해지는 write 액션이므로 표준 canWriteMenu(payments)를 그대로 사용(설계충돌 없음).
export const dynamic = "force-dynamic";

export default async function UserSubscriptionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "payments")) {
    redirect("/dashboard");
  }

  const canForceCancel = canWriteMenu(session.roleCode, "payments");

  const subscriptions = await prisma.userSubscription.findMany({
    include: { user: true, plan: true },
    orderBy: { id: "desc" },
  });

  const statusCount = {
    active: subscriptions.filter((s) => s.status === "active").length,
    cancelled: subscriptions.filter((s) => s.status === "cancelled").length,
    expired: subscriptions.filter((s) => s.status === "expired").length,
    past_due: subscriptions.filter((s) => s.status === "past_due").length,
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">결제/구독 관리 — 구독 현황 조회</h1>
        <p className="mt-1 text-sm text-slate-400">
          회원별 구독 현황을 조회하고, 필요 시 강제 해지(사유 필수)합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/payments/list" className="px-3 py-2 text-slate-400 hover:text-white">
            결제 내역
          </Link>
          <Link href="/payments/refunds" className="px-3 py-2 text-slate-400 hover:text-white">
            환불 처리
          </Link>
          <Link href="/payments/plans" className="px-3 py-2 text-slate-400 hover:text-white">
            구독 플랜 관리
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">구독 현황</span>
          <Link href="/payments/revenue-report" className="px-3 py-2 text-slate-400 hover:text-white">
            매출 리포트
          </Link>
        </nav>
      </div>

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">구독중</p>
          <p className="mt-1 text-2xl font-bold text-emerald-400">{statusCount.active}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">해지됨</p>
          <p className="mt-1 text-2xl font-bold text-slate-400">{statusCount.cancelled}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">만료됨</p>
          <p className="mt-1 text-2xl font-bold text-slate-500">{statusCount.expired}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">결제연체</p>
          <p className="mt-1 text-2xl font-bold text-rose-400">{statusCount.past_due}</p>
        </div>
      </section>

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">플랜</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">시작일</th>
              <th className="px-4 py-3">현재 주기 종료일</th>
              <th className="px-4 py-3">PG 구독 ID</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {subscriptions.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  구독 내역이 없습니다.
                </td>
              </tr>
            )}
            {subscriptions.map((s) => (
              <SubscriptionRow
                key={s.id}
                subscription={{
                  id: s.id,
                  userNickname: s.user.nickname,
                  planName: s.plan.name,
                  status: s.status,
                  startedAt: s.startedAt,
                  currentPeriodEnd: s.currentPeriodEnd,
                  pgSubscriptionId: s.pgSubscriptionId,
                }}
                canForceCancel={canForceCancel}
              />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-4 text-xs text-slate-500">
        04A K-4 명시: status는 active/cancelled/expired/past_due입니다. 강제 해지 시 사유는
        operation_logs에 기록됩니다(별도 사유 컬럼 없음 — 04A 스키마 변경 없이 로그로 추적).
      </p>
    </div>
  );
}
