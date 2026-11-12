import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// [관리자 2.0 전면 재설계 - Task 8] "복주머니결제쿠폰" 그룹의 ① 통합 현황 랜딩 화면.
// 신규 Prisma 모델을 추가하지 않고, 이미 살아있는 기존 원장/모델에서 당일/누적
// 핵심 지표만 모아 보여주는 "요약 허브" 역할만 한다(각 상세 CRUD는 기존 ②~⑥
// 화면이 그대로 담당 — 보고서⑥ "복주머니(Wallet/POINT) 단일 원장 + 3가지 차감
// 경로" 구조를 그대로 반영해, 이 화면에서 3경로 집계를 한 번에 조망할 수 있게 한다).
// RBAC: "pouch" 코드 재사용(복주머니관리 미러링, reward와 동일 권한 레벨).
export const dynamic = "force-dynamic";

function todayStart(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function PouchPaymentOverviewPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "pouch")) {
    redirect("/dashboard");
  }
  const canSeeRevenue = session.roleCode === "super_admin" || session.roleCode === "operator";
  const today = todayStart();

  const [
    walletAgg,
    pointHistoryToday,
    luckybagToday,
    couponActiveCount,
    couponRedeemedToday,
    paymentsToday,
    subscriptionActiveCount,
    recentHistories,
  ] = await Promise.all([
    // 전체 복주머니(Wallet/POINT) 잔액 총합 — "통합 현황" 1번 지표
    prisma.wallet.aggregate({
      where: { currencyType: "POINT", deletedAt: null },
      _sum: { balance: true },
      _count: true,
    }),
    prisma.pointHistory.findMany({
      where: { createdAt: { gte: today } },
      select: { amount: true, type: true, sourceType: true },
    }),
    prisma.luckybagOpenLog.count({ where: { createdAt: { gte: today }, status: "completed" } }),
    prisma.bokjuCoupon.count({ where: { status: { in: ["ISSUED", "ALLOCATED", "DELIVERED", "ASSIGNED"] } } }),
    prisma.bokjuCoupon.count({ where: { redeemedAt: { gte: today } } }),
    prisma.payment.findMany({ where: { status: "paid", createdAt: { gte: today } }, select: { amount: true } }),
    prisma.userSubscription.count({ where: { status: "active" } }),
    prisma.pointHistory.findMany({
      orderBy: { createdAt: "desc" },
      take: 8,
      include: { user: { select: { nickname: true } } },
    }),
  ]);

  const pointEarnedToday = pointHistoryToday
    .filter((h) => h.type === "earn")
    .reduce((s, h) => s + h.amount, 0);
  const pointSpentToday = pointHistoryToday
    .filter((h) => h.type === "spend")
    .reduce((s, h) => s + Math.abs(h.amount), 0);

  // [보고서⑥ §2 "복주머니 차감 3가지 경로"] ①결과보기 공용게이트 ②소원방 송금형
  // ③궁합지도 잠금해제형 — source_type 전체를 정밀 분류하지는 못하지만(후속 과제),
  // 식별 가능한 송금/잠금해제 트리거만 당일 건수로 별도 집계해 구조를 가시화한다.
  const sendBokCount = pointHistoryToday.filter((h) => h.sourceType === "send_bok").length;
  const gunghapUnlockCount = pointHistoryToday.filter((h) => h.sourceType === "gunghap_unlock").length;
  const resultGateCount = pointHistoryToday.length - sendBokCount - gunghapUnlockCount;

  const revenueToday = paymentsToday.reduce((s, p) => s + p.amount, 0);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">복주머니결제쿠폰 — ① 통합 현황</h1>
        <p className="mt-1 text-sm text-slate-500">
          복주머니(Wallet/POINT 단일 원장) · 마케팅 쿠폰 · 상점 · 결제/구독 핵심 지표를 한 화면에서
          조망합니다(조회 전용). 각 항목을 클릭하면 상세 관리 화면으로 이동합니다.
        </p>
      </div>

      {/* ② 복주머니 규칙/정책 — 원장 총괄 */}
      <section className="mb-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-900">🎁 복주머니(Wallet/POINT) 원장</h2>
          <Link href="/reward/luck-pouch-rules" className="text-xs text-indigo-700 hover:underline">
            ② 규칙/정책 관리 →
          </Link>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">전체 보유 지갑 수</p>
            <p className="mt-1 text-2xl font-bold text-slate-900">
              {walletAgg._count.toLocaleString()}개
            </p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">전체 보유 잔액 합계</p>
            <p className="mt-1 text-2xl font-bold text-slate-900">
              {(walletAgg._sum.balance ?? 0).toLocaleString()}P
            </p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">금일 적립(earn)</p>
            <p className="mt-1 text-2xl font-bold text-emerald-700">+{pointEarnedToday.toLocaleString()}P</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-xs text-slate-500">금일 차감(spend)</p>
            <p className="mt-1 text-2xl font-bold text-amber-700">-{pointSpentToday.toLocaleString()}P</p>
          </div>
        </div>

        {/* 3가지 차감 경로 구조 가시화 (보고서⑥ §2) */}
        <div className="mt-4 rounded-xl border border-slate-200 bg-white p-4">
          <p className="mb-3 text-xs font-medium text-slate-500">
            금일 거래 발생 경로 (3가지 차감/적립 트리거 — 전부 동일 Wallet/POINT 원장을 사용)
          </p>
          <div className="flex flex-wrap gap-6">
            <div>
              <p className="text-xs text-slate-500">① 결과보기 공용 게이트(추정)</p>
              <p className="text-lg font-bold text-slate-900">{resultGateCount.toLocaleString()}건</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">② 소원방 송금형(send_bok)</p>
              <p className="text-lg font-bold text-slate-900">{sendBokCount.toLocaleString()}건</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">③ 궁합지도 잠금해제형(gunghap_unlock)</p>
              <p className="text-lg font-bold text-slate-900">{gunghapUnlockCount.toLocaleString()}건</p>
            </div>
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* ③ 마케팅 쿠폰 */}
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-900">🎟 마케팅 쿠폰</h2>
            <Link href="/bokju-coupons/campaigns" className="text-xs text-indigo-700 hover:underline">
              ③ 캠페인 관리 →
            </Link>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-xs text-slate-500">발급/배정 중인 쿠폰</p>
              <p className="mt-1 text-2xl font-bold text-slate-900">{couponActiveCount.toLocaleString()}장</p>
            </div>
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-xs text-slate-500">금일 사용(redeemed)</p>
              <p className="mt-1 text-2xl font-bold text-emerald-700">{couponRedeemedToday.toLocaleString()}장</p>
            </div>
          </div>
        </section>

        {/* ④ 상점 */}
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-900">🛍 상점</h2>
            <Link href="/shop/luckybag" className="text-xs text-indigo-700 hover:underline">
              ④ 상점 관리 →
            </Link>
          </div>
          <div className="grid grid-cols-1 gap-4">
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-xs text-slate-500">금일 복주머니뽑기</p>
              <p className="mt-1 text-2xl font-bold text-slate-900">{luckybagToday.toLocaleString()}건</p>
            </div>
          </div>
        </section>
      </div>

      {/* ⑤ 결제/구독 — 정책준비중 스켈레톤 */}
      <section className="mt-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-900">💳 결제/구독</h2>
          <Link href="/payments/plans" className="text-xs text-indigo-700 hover:underline">
            ⑤ 결제/구독 관리로 이동 →
          </Link>
        </div>
        <div className="rounded-xl border border-dashed border-amber-300 bg-amber-100/40 p-4">
          <p className="text-sm font-medium text-amber-800">⚠ 정책준비중 — 실제 PG 연동 전</p>
          <p className="mt-1 text-xs text-amber-700">
            현재 결제는 PG 미연동 Mock 시뮬레이션 상태입니다(status가 실제 결제 검증 없이
            무조건 &quot;paid&quot;로 기록됨 — 보고서④/⑥ 확정 사실). 아래 숫자는 참고용이며
            실결제 연동 전까지 매출 지표로 사용하지 않습니다.
          </p>
          {canSeeRevenue ? (
            <div className="mt-3 flex flex-wrap gap-6">
              <div>
                <p className="text-xs text-amber-700">금일 결제 건수(Mock)</p>
                <p className="text-lg font-bold text-amber-900">{paymentsToday.length.toLocaleString()}건</p>
              </div>
              <div>
                <p className="text-xs text-amber-700">금일 결제 금액 합계(Mock)</p>
                <p className="text-lg font-bold text-amber-900">{revenueToday.toLocaleString()}원</p>
              </div>
              <div>
                <p className="text-xs text-amber-700">활성 구독 건수(Mock)</p>
                <p className="text-lg font-bold text-amber-900">{subscriptionActiveCount.toLocaleString()}건</p>
              </div>
            </div>
          ) : (
            <p className="mt-3 text-xs text-amber-700">권한 없음(매출 관련 위젯 비노출)</p>
          )}
        </div>
      </section>

      {/* ⑥ 거래내역 — 최근 요약 미리보기 */}
      <section className="mt-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-900">📜 최근 거래내역</h2>
          <Link href="/reward/operation-logs" className="text-xs text-indigo-700 hover:underline">
            ⑥ 거래내역 전체 보기 →
          </Link>
        </div>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">일시</th>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">구분</th>
                <th className="px-4 py-3">source_type</th>
                <th className="px-4 py-3">개수</th>
              </tr>
            </thead>
            <tbody>
              {recentHistories.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    최근 거래내역이 없습니다.
                  </td>
                </tr>
              )}
              {recentHistories.map((h) => (
                <tr key={h.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-500">{fmtDate(h.createdAt)}</td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/users/${h.userId}`}
                      className="font-medium text-slate-700 hover:text-indigo-700 hover:underline"
                    >
                      {h.user.nickname}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    {h.type === "earn" ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">적립</span>
                    ) : (
                      <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">차감</span>
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono text-slate-500">{h.sourceType}</td>
                  <td
                    className={`px-4 py-3 font-medium ${h.amount > 0 ? "text-emerald-700" : "text-red-700"}`}
                  >
                    {h.amount > 0 ? "+" : ""}
                    {h.amount.toLocaleString()}개
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
