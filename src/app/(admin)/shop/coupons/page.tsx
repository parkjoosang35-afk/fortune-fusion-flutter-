import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import CouponCreateForm from "@/components/CouponCreateForm";
import CouponRow from "@/components/CouponRow";
import CouponIssueForm from "@/components/CouponIssueForm";

// 05_Admin_System_Design.md §3.4 "상점 관리" — 7차 소단위(도메인 J 4단계): 쿠폰 관리
// 04A J-8 coupons + J-9 coupon_issues CRUD/발급.
// [범위 결정] 원칙⑤(소단위 개발): coupons(마스터) CRUD + 특정 회원에게 단건 발급
//   + 발급 이력 조회까지 이번 소단위에서 다룬다. 이것으로 05§3.4 "상점 관리(부적/
//   복주머니/상품권)" 표의 모든 화면 항목 구현이 완료된다.
// [08§3.2 라우트매핑 보완] 08_Web_Design.md의 상점 관리 라우트 목록에는 giftcards까지만
//   명시되어 있으나(05 문서에 이후 추가된 "쿠폰 관리" 항목 반영 이전 버전으로 추정),
//   기존 /shop/{amulets,luckybag,giftcards} 명명 규칙을 따라 /shop/coupons로 신설한다.
export const dynamic = "force-dynamic";

const ISSUE_STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  unused: { label: "미사용", cls: "bg-emerald-950/60 text-emerald-400" },
  used: { label: "사용완료", cls: "bg-slate-800 text-slate-400" },
  expired: { label: "만료", cls: "bg-rose-950/60 text-rose-400" },
};

function fmtDate(d: Date | null): string {
  return d ? d.toISOString().slice(0, 19).replace("T", " ") : "-";
}

export default async function ShopCouponsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.write;
  const canDelete = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.delete;

  const now = new Date();

  const coupons = await prisma.coupon.findMany({
    where: { deletedAt: null },
    orderBy: { id: "asc" },
    include: { _count: { select: { issues: { where: { deletedAt: null } } } } },
  });

  const issues = await prisma.couponIssue.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: 30,
    include: {
      coupon: { select: { code: true } },
      user: { select: { nickname: true } },
    },
  });

  const users = await prisma.user.findMany({
    where: { deletedAt: null },
    orderBy: { id: "asc" },
    take: 100,
    select: { id: true, nickname: true },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">상점 관리 — 쿠폰</h1>
        <p className="mt-1 text-sm text-slate-400">
          쿠폰(할인율/포인트 고정 할인)을 등록/관리하고, 특정 회원에게 개별 발급합니다.
          발급 한도(usage_limit)를 초과하는 발급은 시스템이 자동으로 차단합니다.
        </p>
      </div>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">쿠폰 관리</h2>
        <CouponCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">코드</th>
                <th className="px-4 py-3">할인</th>
                <th className="px-4 py-3">유효기간</th>
                <th className="px-4 py-3">발급/한도</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {coupons.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 쿠폰이 없습니다.
                  </td>
                </tr>
              )}
              {coupons.map((c) => (
                <CouponRow
                  key={c.id}
                  coupon={{
                    id: c.id,
                    code: c.code,
                    discountType: c.discountType,
                    discountValue: c.discountValue,
                    validFrom: c.validFrom,
                    validTo: c.validTo,
                    usageLimit: c.usageLimit,
                    issuedCount: c._count.issues,
                    isExpired: c.validTo < now,
                  }}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          04A J-8 명시: usage_limit은 전체 사용 가능 횟수(NULL=무제한)입니다. 코드(code)는
          UQ 제약이 있어 등록 후 수정할 수 없습니다.
        </p>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">쿠폰 발급</h2>
        <CouponIssueForm
          canWrite={canWrite}
          coupons={coupons.map((c) => ({ id: c.id, code: c.code }))}
          users={users}
        />
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">쿠폰 발급 이력 (최근 30건)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">쿠폰코드</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">발급 시각</th>
                <th className="px-4 py-3">사용 시각</th>
              </tr>
            </thead>
            <tbody>
              {issues.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    발급 이력이 없습니다.
                  </td>
                </tr>
              )}
              {issues.map((iss) => {
                const st = ISSUE_STATUS_LABEL[iss.status] ?? {
                  label: iss.status,
                  cls: "bg-slate-800 text-slate-400",
                };
                return (
                  <tr key={iss.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 text-slate-200">{iss.user.nickname}</td>
                    <td className="px-4 py-3 font-mono text-slate-300">{iss.coupon.code}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(iss.issuedAt)}</td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(iss.usedAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 쿠폰 사용 처리(status: unused→used)와 만료 배치
          처리(→expired)는 회원 앱/배치 시스템에서 이루어지며, 이 화면은 발급까지의
          관리자 기능만 제공합니다.
        </p>
      </section>
    </div>
  );
}
