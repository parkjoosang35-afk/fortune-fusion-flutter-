import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.7 "결제/구독 관리" — 1차 소단위: K-1 결제 내역 조회
// 04A K-1 payments 조회.
// [범위 결정] 05§3.7 화면 스펙: "결제 내역 조회 | payments — 조회 전용, 삭제
//   버튼 자체를 UI에서 제공하지 않음(04A K도메인 '삭제 절대 금지' 원칙의 UI
//   레벨 강제)". 04A 절대원칙 3번("결제/포인트는 관리자 화면에서도 직접
//   수정 절대 금지")과도 정확히 일치하므로, 이번 소단위는 Server Action을
//   전혀 두지 않는다(원칙② 설계충돌 방지 — 두 문서 모두 애매함 없이 일치).
// [deleted_at 미사용] 04A 명시대로 이 테이블의 deletedAt은 애플리케이션
//   레벨에서 절대 참조하지 않는다(schema.prisma Payment 모델 주석과 동일
//   근거) — 아래 조회 쿼리에 `where: { deletedAt: null }`을 의도적으로
//   사용하지 않는다(다른 모든 테이블과 다른 유일한 예외).
// [RBAC] 05§5.2: "결제/구독 관리 | super_admin:RWD, operator:R(+환불요청),
//   cs:R, content_manager:✕". 이 화면은 4역할 모두(content_manager 제외)
//   read 권한이 있고, 이번 소단위는 조회 전용이므로 canAccessMenu만으로
//   충분하다(canWriteMenu는 2차 소단위 환불 처리에서 사용).
export const dynamic = "force-dynamic";

const ORDER_TYPE_LABEL: Record<string, string> = {
  subscription: "구독",
  giftcard: "상품권",
  amulet: "디지털부적",
  luckybag: "복주머니",
};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  paid: { label: "결제완료", cls: "bg-emerald-100 text-emerald-700" },
  failed: { label: "결제실패", cls: "bg-rose-100 text-rose-700" },
  cancelled: { label: "취소됨", cls: "bg-white text-slate-500" },
};

const PAGE_SIZE = 20;

interface PaymentsListPageProps {
  searchParams: Promise<{
    orderType?: string;
    status?: string;
    page?: string;
  }>;
}

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function PaymentsListPage({ searchParams }: PaymentsListPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "payments")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const orderTypeFilter = params.orderType ?? "";
  const statusFilter = params.status ?? "";
  const page = Math.max(1, Number(params.page ?? "1") || 1);

  // 04A K-1 명시: deleted_at 컬럼은 존재하되 애플리케이션 레벨에서 사용
  // 금지(정책적 무시) — where 조건에 deletedAt을 포함하지 않는다.
  const where: { orderType?: string; status?: string } = {};
  if (orderTypeFilter) where.orderType = orderTypeFilter;
  if (statusFilter) where.status = statusFilter;

  const [totalCount, payments] = await Promise.all([
    prisma.payment.count({ where }),
    prisma.payment.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
  ]);

  // 오늘자 결제 매출 합계(대시보드 위젯 스펙 05§3.0과 동일 쿼리 원칙 — status=paid)
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayPayments = await prisma.payment.findMany({
    where: { status: "paid", createdAt: { gte: todayStart } },
    select: { amount: true },
  });
  const todayRevenue = todayPayments.reduce((s, p) => s + p.amount, 0);

  const userIds = [...new Set(payments.map((p) => p.userId))];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));
  const nick = (id: number) => userMap.get(id) ?? `회원#${id}`;

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));

  function buildQuery(next: Record<string, string | number>) {
    const merged = { orderType: orderTypeFilter, status: statusFilter, page, ...next };
    const sp = new URLSearchParams();
    if (merged.orderType) sp.set("orderType", String(merged.orderType));
    if (merged.status) sp.set("status", String(merged.status));
    if (merged.page && Number(merged.page) > 1) sp.set("page", String(merged.page));
    const qs = sp.toString();
    return qs ? `?${qs}` : "";
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">결제/구독 관리 — 결제 내역 조회</h1>
        <p className="mt-1 text-sm text-slate-500">
          회원의 결제 내역을 조회합니다(조회 전용). 04A K도메인 &quot;삭제 절대 금지&quot; 원칙에 따라
          삭제 기능을 제공하지 않습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">결제 내역</span>
          <Link href="/payments/refunds" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            환불 처리
          </Link>
          <Link href="/payments/plans" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            구독 플랜 관리
          </Link>
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
          <p className="text-xs text-slate-500">전체 결제 건수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">금일 결제 매출(paid)</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">
            {todayRevenue.toLocaleString()}원
          </p>
        </div>
      </section>

      <div className="mb-4 flex flex-wrap gap-2">
        <Link
          href={buildQuery({ orderType: "", page: 1 })}
          className={`rounded-lg px-3 py-1.5 text-xs ${
            !orderTypeFilter ? "bg-indigo-600 text-white" : "bg-white text-slate-500 hover:text-slate-900"
          }`}
        >
          전체 유형
        </Link>
        {Object.entries(ORDER_TYPE_LABEL).map(([key, label]) => (
          <Link
            key={key}
            href={buildQuery({ orderType: key, page: 1 })}
            className={`rounded-lg px-3 py-1.5 text-xs ${
              orderTypeFilter === key ? "bg-indigo-600 text-white" : "bg-white text-slate-500 hover:text-slate-900"
            }`}
          >
            {label}
          </Link>
        ))}
        <span className="mx-2 self-center text-slate-600">|</span>
        <Link
          href={buildQuery({ status: "", page: 1 })}
          className={`rounded-lg px-3 py-1.5 text-xs ${
            !statusFilter ? "bg-indigo-600 text-white" : "bg-white text-slate-500 hover:text-slate-900"
          }`}
        >
          전체 상태
        </Link>
        {Object.entries(STATUS_LABEL).map(([key, { label }]) => (
          <Link
            key={key}
            href={buildQuery({ status: key, page: 1 })}
            className={`rounded-lg px-3 py-1.5 text-xs ${
              statusFilter === key ? "bg-indigo-600 text-white" : "bg-white text-slate-500 hover:text-slate-900"
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">금액</th>
              <th className="px-4 py-3">PG사</th>
              <th className="px-4 py-3">PG 거래ID</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">결제일</th>
            </tr>
          </thead>
          <tbody>
            {payments.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  조회된 결제 내역이 없습니다.
                </td>
              </tr>
            )}
            {payments.map((p) => {
              const statusInfo = STATUS_LABEL[p.status] ?? { label: p.status, cls: "bg-white text-slate-500" };
              return (
                <tr key={p.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-700">{nick(p.userId)}</td>
                  <td className="px-4 py-3 text-slate-600">{ORDER_TYPE_LABEL[p.orderType] ?? p.orderType}</td>
                  <td className="px-4 py-3 text-slate-700">
                    {p.amount.toLocaleString()} {p.currencyCode}
                  </td>
                  <td className="px-4 py-3 text-slate-500">{p.pgProvider}</td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">{p.pgTxId}</td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs ${statusInfo.cls}`}>
                      {statusInfo.label}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(p.createdAt)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="mt-4 flex justify-center gap-2">
          {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
            <Link
              key={p}
              href={buildQuery({ page: p })}
              className={`rounded-lg px-3 py-1.5 text-xs ${
                p === page ? "bg-indigo-600 text-white" : "bg-white text-slate-500 hover:text-slate-900"
              }`}
            >
              {p}
            </Link>
          ))}
        </div>
      )}

      <p className="mt-4 text-xs text-slate-500">
        04A K-1 명시: order_type은 subscription/giftcard/amulet/luckybag, status는
        paid/failed/cancelled입니다. pg_tx_id는 PG사 거래ID(UQ)입니다.
      </p>
    </div>
  );
}
