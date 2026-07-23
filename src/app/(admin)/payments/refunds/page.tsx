import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import RefundRow from "@/components/RefundRow";
import RefundRequestForm from "@/components/RefundRequestForm";

// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 2차 소단위: 환불 처리 (K-2 payment_refunds)
// [범위 결정] 05§3.7: "환불 처리 | payment_refunds 신규 생성 워크플로우
//   (원본 payments는 상태만 변경)". 04A 절대원칙3에 따라 원본 payments의
//   금액/거래ID는 절대 직접 수정하지 않고, payment_refunds에 신규 이력을
//   생성한 뒤 승인 시점에만 payments.status를 cancelled로 전환한다
//   (actions/payment-refunds.ts, schema.prisma PaymentRefund 모델 주석 참조).
// [RBAC 2단계 승인 구조] 05§5.2: "결제/구독 관리 | operator: R(+환불요청,
//   최종승인은 super_admin)". 이 화면은:
//   - 환불 요청 생성 폼: super_admin/operator에게만 노출(canRequestRefund)
//   - 승인/거부 버튼: super_admin에게만 노출(canApproveRefund)
//   - cs: 목록 조회만 가능(payments=R), content_manager: 접근 불가(payments=X)
export const dynamic = "force-dynamic";

export default async function PaymentRefundsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "payments")) {
    redirect("/dashboard");
  }

  const canRequest = session.roleCode === "super_admin" || session.roleCode === "operator";
  const canApprove = session.roleCode === "super_admin";

  const refunds = await prisma.paymentRefund.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
    include: { payment: { select: { pgTxId: true, userId: true } } },
  });

  const userIds = [...new Set(refunds.map((r) => r.payment.userId))];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));

  // 환불 요청 생성 폼에 노출할 "요청 가능한 결제 내역" 후보:
  // status=paid(취소되지 않은 결제) AND 대기중(pending) 환불요청이 없는 건
  let eligiblePayments: { id: number; pgTxId: string; userNickname: string; amount: number }[] = [];
  if (canRequest) {
    const paidPayments = await prisma.payment.findMany({
      where: { status: "paid" },
      orderBy: { createdAt: "desc" },
    });
    const pendingPaymentIds = new Set(
      (await prisma.paymentRefund.findMany({ where: { status: "pending" }, select: { paymentId: true } })).map(
        (r) => r.paymentId
      )
    );
    const eligible = paidPayments.filter((p) => !pendingPaymentIds.has(p.id));
    const eligibleUserIds = [...new Set(eligible.map((p) => p.userId))];
    const eligibleUsers = await prisma.user.findMany({
      where: { id: { in: eligibleUserIds } },
      select: { id: true, nickname: true },
    });
    const eligibleUserMap = new Map(eligibleUsers.map((u) => [u.id, u.nickname]));
    eligiblePayments = eligible.map((p) => ({
      id: p.id,
      pgTxId: p.pgTxId,
      userNickname: eligibleUserMap.get(p.userId) ?? `회원#${p.userId}`,
      amount: p.amount,
    }));
  }

  const pendingCount = refunds.filter((r) => r.status === "pending").length;
  const completedCount = refunds.filter((r) => r.status === "completed").length;
  const failedCount = refunds.filter((r) => r.status === "failed").length;
  const totalRefundedAmount = refunds
    .filter((r) => r.status === "completed")
    .reduce((s, r) => s + r.amount, 0);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">결제/구독 관리 — 환불 처리</h1>
        <p className="mt-1 text-sm text-slate-400">
          환불은 원본 결제를 직접 수정하지 않고, payment_refunds에 별도 이력을 생성하는 방식으로만 처리합니다.
          최종 승인은 super_admin만 가능합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/payments/list" className="px-3 py-2 text-slate-400 hover:text-white">
            결제 내역
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">환불 처리</span>
          <Link href="/payments/plans" className="px-3 py-2 text-slate-400 hover:text-white">
            구독 플랜 관리
          </Link>
          <Link href="/payments/subscriptions" className="px-3 py-2 text-slate-400 hover:text-white">
            구독 현황
          </Link>
          <Link href="/payments/revenue-report" className="px-3 py-2 text-slate-400 hover:text-white">
            매출 리포트
          </Link>
        </nav>
      </div>

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">승인 대기</p>
          <p className="mt-1 text-2xl font-bold text-amber-400">{pendingCount}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">환불 완료</p>
          <p className="mt-1 text-2xl font-bold text-emerald-400">{completedCount}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">거부됨</p>
          <p className="mt-1 text-2xl font-bold text-rose-400">{failedCount}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-xs text-slate-500">총 환불 금액(완료건)</p>
          <p className="mt-1 text-2xl font-bold text-white">{totalRefundedAmount.toLocaleString()}원</p>
        </div>
      </section>

      {canRequest ? (
        <RefundRequestForm eligiblePayments={eligiblePayments} />
      ) : (
        <p className="mb-6 rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-500">
          환불 요청 생성 권한이 없습니다(조회만 가능).
        </p>
      )}

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">PG 거래ID</th>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">환불 금액</th>
              <th className="px-4 py-3">사유</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">요청일</th>
              <th className="px-4 py-3">처리일</th>
              <th className="px-4 py-3">처리</th>
            </tr>
          </thead>
          <tbody>
            {refunds.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-10 text-center text-slate-500">
                  환불 요청 내역이 없습니다.
                </td>
              </tr>
            )}
            {refunds.map((r) => (
              <RefundRow
                key={r.id}
                refund={{
                  id: r.id,
                  paymentId: r.paymentId,
                  pgTxId: r.payment.pgTxId,
                  userNickname: userMap.get(r.payment.userId) ?? `회원#${r.payment.userId}`,
                  amount: r.amount,
                  reason: r.reason,
                  status: r.status,
                  processedAt: r.processedAt,
                  createdAt: r.createdAt,
                }}
                canApprove={canApprove}
              />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-4 text-xs text-slate-500">
        04A K-2 명시: status는 pending/completed/failed입니다. 승인 시 원본 payments.status만 cancelled로
        변경되며, amount/pg_tx_id 등 다른 필드는 절대 직접 수정하지 않습니다.
      </p>
    </div>
  );
}
