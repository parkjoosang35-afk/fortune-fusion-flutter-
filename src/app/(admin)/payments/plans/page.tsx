import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import SubscriptionPlanCreateForm from "@/components/SubscriptionPlanCreateForm";
import SubscriptionPlanRow from "@/components/SubscriptionPlanRow";

// [2026-11-11 신통방통 관리자 2.0 전면 재설계 - 구독 "정책준비중" 전환]
// 과거 더미 플랜 4개(베이직/프리미엄 월간·연간)는 앱 미출시 상태의 테스트 시드
// 데이터로 확인되어 완전삭제했다(사용자 확정: "앱 출시도 안했는데 무슨 구독자냐").
// 화면 자체(CRUD 폼/목록)는 "구독 가격 정책이 확정되면 바로 플랜을 등록할 수 있는"
// 뼈대로 그대로 유지하되, 상단에 "정책 준비중" 안내 배너를 추가한다. 플랜을 실제로
// 등록하는 순간 /api/public/subscription/* 전체가 자동으로 재가동된다(코드 변경 불필요).
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
        <h1 className="text-2xl font-bold text-slate-900">복주머니·결제·쿠폰 — 구독상품 관리</h1>
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
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">구독상품 관리</span>
          <Link href="/payments/subscriptions" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            구독 현황
          </Link>
          <Link href="/payments/revenue-report" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            매출 리포트
          </Link>
        </nav>
      </div>

      <div className="mb-6 rounded-xl border border-amber-300 bg-amber-50 p-4">
        <p className="text-sm font-semibold text-amber-900">⚠️ 정책 준비중</p>
        <p className="mt-1 text-xs text-amber-800">
          신통방통은 아직 구독 서비스를 출시하지 않았습니다(과거 테스트 더미 플랜/구독/결제 데이터는
          2026-11-11 전면 재설계 시 전부 삭제됨). 가격·혜택 정책이 확정되기 전까지는 아래에서 플랜을
          생성하지 마세요. 플랜이 1개라도 등록되면 앱의 구독 가입 API가 즉시 활성화됩니다.
        </p>
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
                  등록된 구독 플랜이 없습니다(정책 준비중).
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
        삭제 시 실제 레코드는 유지되며 isActive가 false로 전환됩니다(soft delete).
      </p>
    </div>
  );
}
