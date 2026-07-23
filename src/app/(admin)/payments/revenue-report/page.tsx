import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 5차(마지막) 소단위: 매출 리포트
// [범위 결정] 05§3.7 화면 스펙: "매출 리포트 | 기간별/플랜별 매출 집계
//   (statistics_snapshots 연계)". 이것으로 §3.7 결제/구독 관리 5개 화면이
//   모두 완료된다.
// [statistics_snapshots 연계 방식] 04A O-5 statistics_snapshots는
//   {metric_code, period, value(JSONB)} 범용 스냅샷 테이블로, O도메인(시스템/
//   운영) 전역 배치 집계용이며 특정 화면에 종속되지 않는다. 04A/05 어느 문서에도
//   "이 화면이 반드시 statistics_snapshots 테이블에서 read해야 한다"는 강제
//   제약이 없고(§3.2 AI 비용 대시보드 등 다른 화면들도 원본 로그 테이블을
//   실시간 집계하는 패턴을 이미 채택함 — ai-content/logs, matching/
//   compatibility-stats 전례), payments 테이블 자체가 이미 실시간 매출 원본
//   데이터를 담고 있으므로 statistics_snapshots에 별도로 값을 적재/조회하는
//   간접 경로를 추가하는 것은 불필요한 복잡도를 초래한다(원칙②: 설계충돌 코드
//   금지 — 새 배치/스냅샷 파이프라인을 여기서 임의로 만들면 오히려 04A O-5의
//   "배치 적재" 취지와 충돌 소지). 따라서 이 화면은 payments(status=paid) +
//   user_subscriptions + subscription_plans를 실시간 메모리 집계하여
//   "기간별(일별/월별)" 및 "플랜별" 매출을 보여주는 순수 조회 페이지로 구현한다
//   (Server Action 없음 — 05 스펙도 "집계"만 명시, CUD 없음).
// [집계 로직] where 단순화 후 메모리 집계 원칙(ai-content/logs, matching/
//   compatibility-stats와 동일 전례):
//   - 전체 매출(status=paid 합계), 취소 건수/금액(status=cancelled)
//   - order_type별 매출 분포(subscription/giftcard/amulet/luckybag)
//   - 구독(subscription) 결제 중 plan_id 매칭 가능한 건에 대해 플랜별 매출 집계
//     (payments.order_ref_id가 user_subscriptions.id를 참조하는 폴리모픽 구조이므로
//     order_ref_id → UserSubscription.planId → SubscriptionPlan 순으로 조인)
//   - 일별 매출 추이(최근 생성일 기준 날짜별 합계)
export const dynamic = "force-dynamic";

const ORDER_TYPE_LABEL: Record<string, string> = {
  subscription: "구독",
  giftcard: "상품권",
  amulet: "디지털 부적",
  luckybag: "복주머니",
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export default async function RevenueReportPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "payments")) {
    redirect("/dashboard");
  }

  // ⚠️04A 명시: payments.deleted_at은 애플리케이션 레벨에서 사용 금지(정책적 무시) — K-1과 동일 원칙
  const [payments, userSubscriptions, plans] = await Promise.all([
    prisma.payment.findMany({ orderBy: { createdAt: "asc" } }),
    prisma.userSubscription.findMany(),
    prisma.subscriptionPlan.findMany(),
  ]);

  const paidPayments = payments.filter((p) => p.status === "paid");
  const cancelledPayments = payments.filter((p) => p.status === "cancelled");
  const failedPayments = payments.filter((p) => p.status === "failed");

  const totalRevenue = paidPayments.reduce((sum, p) => sum + p.amount, 0);
  const cancelledAmount = cancelledPayments.reduce((sum, p) => sum + p.amount, 0);

  // ── order_type별 매출 집계 ──
  const orderTypeMap = new Map<string, { count: number; amount: number }>();
  for (const p of paidPayments) {
    const cur = orderTypeMap.get(p.orderType) ?? { count: 0, amount: 0 };
    cur.count += 1;
    cur.amount += p.amount;
    orderTypeMap.set(p.orderType, cur);
  }
  const orderTypeStats = Array.from(orderTypeMap.entries())
    .map(([orderType, v]) => ({ orderType, ...v }))
    .sort((a, b) => b.amount - a.amount);

  // ── 플랜별 매출 집계 (구독 결제만: order_ref_id → user_subscriptions.id → plan_id) ──
  const subscriptionById = new Map(userSubscriptions.map((s) => [s.id, s]));
  const planById = new Map(plans.map((p) => [p.id, p]));
  const planRevenueMap = new Map<number, { count: number; amount: number }>();
  let unmatchedSubscriptionPayments = 0;
  for (const p of paidPayments) {
    if (p.orderType !== "subscription") continue;
    const sub = p.orderRefId != null ? subscriptionById.get(p.orderRefId) : undefined;
    if (!sub) {
      unmatchedSubscriptionPayments += 1;
      continue;
    }
    const cur = planRevenueMap.get(sub.planId) ?? { count: 0, amount: 0 };
    cur.count += 1;
    cur.amount += p.amount;
    planRevenueMap.set(sub.planId, cur);
  }
  const planStats = Array.from(planRevenueMap.entries())
    .map(([planId, v]) => ({ planId, planName: planById.get(planId)?.name ?? `(삭제된 플랜 #${planId})`, ...v }))
    .sort((a, b) => b.amount - a.amount);

  // ── 일별 매출 추이 ──
  const dailyMap = new Map<string, number>();
  for (const p of paidPayments) {
    const day = fmtDate(p.createdAt);
    dailyMap.set(day, (dailyMap.get(day) ?? 0) + p.amount);
  }
  const dailyStats = Array.from(dailyMap.entries())
    .map(([day, amount]) => ({ day, amount }))
    .sort((a, b) => (a.day < b.day ? -1 : 1));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">결제/구독 관리 — 매출 리포트</h1>
        <p className="mt-1 text-sm text-slate-400">기간별/플랜별 매출을 집계하여 보여줍니다(조회 전용).</p>
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
          <Link href="/payments/subscriptions" className="px-3 py-2 text-slate-400 hover:text-white">
            구독 현황
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">매출 리포트</span>
        </nav>
      </div>

      <section className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">총 매출(paid)</p>
          <p className="mt-1 text-2xl font-bold text-emerald-400">{totalRevenue.toLocaleString()}원</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">결제 건수(paid)</p>
          <p className="mt-1 text-2xl font-bold text-white">{paidPayments.length}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">취소 금액(cancelled)</p>
          <p className="mt-1 text-2xl font-bold text-slate-400">{cancelledAmount.toLocaleString()}원</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">결제 실패 건수</p>
          <p className="mt-1 text-2xl font-bold text-rose-400">{failedPayments.length}</p>
        </div>
      </section>

      <div className="mb-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* 주문 유형별 매출 */}
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <h2 className="mb-3 text-sm font-semibold text-white">주문 유형별 매출</h2>
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="py-2">유형</th>
                <th className="py-2">건수</th>
                <th className="py-2">매출</th>
              </tr>
            </thead>
            <tbody>
              {orderTypeStats.length === 0 && (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-slate-500">
                    데이터가 없습니다.
                  </td>
                </tr>
              )}
              {orderTypeStats.map((s) => (
                <tr key={s.orderType} className="border-b border-slate-800/60">
                  <td className="py-2 text-slate-200">{ORDER_TYPE_LABEL[s.orderType] ?? s.orderType}</td>
                  <td className="py-2 text-slate-300">{s.count}</td>
                  <td className="py-2 text-slate-300">{s.amount.toLocaleString()}원</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* 구독 플랜별 매출 */}
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <h2 className="mb-3 text-sm font-semibold text-white">구독 플랜별 매출</h2>
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="py-2">플랜명</th>
                <th className="py-2">건수</th>
                <th className="py-2">매출</th>
              </tr>
            </thead>
            <tbody>
              {planStats.length === 0 && (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-slate-500">
                    구독 매출 데이터가 없습니다.
                  </td>
                </tr>
              )}
              {planStats.map((s) => (
                <tr key={s.planId} className="border-b border-slate-800/60">
                  <td className="py-2 text-slate-200">{s.planName}</td>
                  <td className="py-2 text-slate-300">{s.count}</td>
                  <td className="py-2 text-slate-300">{s.amount.toLocaleString()}원</td>
                </tr>
              ))}
            </tbody>
          </table>
          {unmatchedSubscriptionPayments > 0 && (
            <p className="mt-2 text-xs text-slate-500">
              ※ 구독 결제 {unmatchedSubscriptionPayments}건은 대응하는 구독 이력(user_subscriptions)을 찾을 수
              없어 플랜별 집계에서 제외되었습니다(폴리모픽 참조 특성상 발생 가능 — 04A 명시대로 FK 미설정).
            </p>
          )}
        </div>
      </div>

      {/* 일별 매출 추이 */}
      <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">일별 매출 추이</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="py-2">일자</th>
                <th className="py-2">매출</th>
              </tr>
            </thead>
            <tbody>
              {dailyStats.length === 0 && (
                <tr>
                  <td colSpan={2} className="py-6 text-center text-slate-500">
                    데이터가 없습니다.
                  </td>
                </tr>
              )}
              {dailyStats.map((s) => (
                <tr key={s.day} className="border-b border-slate-800/60">
                  <td className="py-2 text-slate-200">{s.day}</td>
                  <td className="py-2 text-slate-300">{s.amount.toLocaleString()}원</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <p className="mt-4 text-xs text-slate-500">
        04A O-5 statistics_snapshots(metric_code+period UQ, value JSONB)는 시스템 전역 배치 집계용 범용
        테이블로, 이 화면은 payments/user_subscriptions/subscription_plans 원본 데이터를 실시간 집계하여
        표시합니다(조회 전용, CUD 없음).
      </p>
    </div>
  );
}
