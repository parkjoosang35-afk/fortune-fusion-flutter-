import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";

// [복주머니 마케팅 쿠폰 최종본 §37 화면⑥ "쿠폰 사용 내역"]
// coupon_redemption 테이블을 그대로 조회하는 화면 — 등록/적립 성공(SUCCESS)뿐
// 아니라 중복(DUPLICATE)/만료(EXPIRED)/중지(REVOKED)/대상아님(NOT_TARGET)/
// 유효하지않음(INVALID) 실패 이력까지 전부 보여준다(성공만 보여주면 안 됨 —
// 원본 명세 "실패 이력" 요구사항). BokjuCouponRedemption에는 User/BokjuCoupon에
// 대한 Prisma relation이 없으므로(스키마 설계상 단순 FK 컬럼만 보유) include를
// 쓸 수 없고, 회원 닉네임·쿠폰번호·캠페인명을 별도 조회 후 메모리에서 매핑한다.
export const dynamic = "force-dynamic";

const PAGE_SIZE = 30;

const RESULT_LABEL: Record<string, { label: string; className: string }> = {
  SUCCESS: { label: "성공(등록·적립)", className: "bg-emerald-100 text-emerald-700" },
  DUPLICATE: { label: "중복 차단", className: "bg-amber-100 text-amber-700" },
  EXPIRED: { label: "기간 만료", className: "bg-slate-100 text-slate-600" },
  REVOKED: { label: "중지/회수됨", className: "bg-rose-100 text-rose-700" },
  NOT_TARGET: { label: "대상 아님", className: "bg-orange-100 text-orange-700" },
  INVALID: { label: "유효하지 않음", className: "bg-rose-100 text-rose-700" },
};

interface UsagePageProps {
  searchParams: Promise<{
    page?: string;
    campaignId?: string;
    result?: string;
  }>;
}

export default async function BokjuCouponUsagePage({ searchParams }: UsagePageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const page = Math.max(1, Number(params.page ?? "1") || 1);
  const campaignIdFilter = params.campaignId ? Number(params.campaignId) : undefined;
  const resultFilter = params.result && params.result in RESULT_LABEL ? params.result : undefined;

  const where = {
    ...(campaignIdFilter ? { campaignId: campaignIdFilter } : {}),
    ...(resultFilter ? { result: resultFilter } : {}),
  };

  const [total, redemptions, campaigns, summaryRaw] = await Promise.all([
    prisma.bokjuCouponRedemption.count({ where }),
    prisma.bokjuCouponRedemption.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
    prisma.bokjuCouponCampaign.findMany({
      select: { id: true, title: true },
      orderBy: { createdAt: "desc" },
    }),
    // 필터 조건은 그대로 유지한 채 결과 유형별 집계만 별도로 낸다(상단 요약 카드용).
    prisma.bokjuCouponRedemption.groupBy({
      by: ["result"],
      where: campaignIdFilter ? { campaignId: campaignIdFilter } : {},
      _count: { _all: true },
    }),
  ]);
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const summary = Object.fromEntries(summaryRaw.map((s) => [s.result, s._count._all]));

  // 회원 닉네임 / 쿠폰번호를 메모리에서 매핑(관계 없는 FK 컬럼이므로 배치 조회 후 매핑).
  const userIds = Array.from(new Set(redemptions.map((r) => r.userId).filter((v): v is number => v !== null)));
  const couponIds = Array.from(new Set(redemptions.map((r) => r.couponId).filter((v): v is number => v !== null)));
  const campaignIds = Array.from(new Set(redemptions.map((r) => r.campaignId).filter((v): v is number => v !== null)));

  const [users, coupons, redemptionCampaigns] = await Promise.all([
    userIds.length
      ? prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, nickname: true, email: true } })
      : Promise.resolve([]),
    couponIds.length
      ? prisma.bokjuCoupon.findMany({ where: { id: { in: couponIds } }, select: { id: true, couponNo: true } })
      : Promise.resolve([]),
    campaignIds.length
      ? prisma.bokjuCouponCampaign.findMany({ where: { id: { in: campaignIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
  ]);
  const userById = new Map(users.map((u) => [u.id, u]));
  const couponById = new Map(coupons.map((c) => [c.id, c.couponNo]));
  const campaignById = new Map(redemptionCampaigns.map((c) => [c.id, c.title]));

  const filterQuery = {
    ...(campaignIdFilter ? { campaignId: String(campaignIdFilter) } : {}),
    ...(resultFilter ? { result: resultFilter } : {}),
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 쿠폰 사용 내역</h1>
        <p className="mt-1 text-sm text-slate-500">
          쿠폰 등록(QR/링크) 시도 전체를 기록합니다. 성공(등록·적립)뿐 아니라 중복 차단, 만료,
          중지/회수, 대상 아님, 유효하지 않음 등 실패 이력도 함께 확인할 수 있습니다(조회 전용).
        </p>
      </div>

      <BokjuCouponSubNav />

      {/* 결과 유형별 요약 카드 — 현재 캠페인 필터는 반영하되 result 필터와는 무관하게 전체 분포를 보여준다 */}
      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        {Object.entries(RESULT_LABEL).map(([code, meta]) => (
          <div key={code} className="rounded-xl border border-slate-200 bg-white p-3">
            <p className="text-xs text-slate-500">{meta.label}</p>
            <p className="mt-1 text-xl font-bold text-slate-900">{summary[code] ?? 0}</p>
          </div>
        ))}
      </div>

      <form
        method="GET"
        className="mb-4 flex flex-wrap items-center gap-3 rounded-xl border border-slate-200 bg-white p-4"
      >
        <select
          name="campaignId"
          defaultValue={campaignIdFilter ? String(campaignIdFilter) : ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 캠페인</option>
          {campaigns.map((c) => (
            <option key={c.id} value={c.id}>
              {c.title}
            </option>
          ))}
        </select>
        <select
          name="result"
          defaultValue={resultFilter ?? ""}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        >
          <option value="">전체 결과</option>
          {Object.entries(RESULT_LABEL).map(([code, meta]) => (
            <option key={code} value={code}>
              {meta.label}
            </option>
          ))}
        </select>
        <button
          type="submit"
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
        >
          필터 적용
        </button>
        <span className="ml-auto text-xs text-slate-400">전체 {total.toLocaleString()}건</span>
      </form>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">일시</th>
              <th className="px-4 py-3">캠페인</th>
              <th className="px-4 py-3">회원</th>
              <th className="px-4 py-3">쿠폰번호</th>
              <th className="px-4 py-3">결과</th>
              <th className="px-4 py-3">실패 사유</th>
              <th className="px-4 py-3">지급 개수</th>
              <th className="px-4 py-3">처리 후 보유</th>
            </tr>
          </thead>
          <tbody>
            {redemptions.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-10 text-center text-slate-500">
                  조건에 맞는 사용 내역이 없습니다.
                </td>
              </tr>
            )}
            {redemptions.map((r) => {
              const meta = RESULT_LABEL[r.result] ?? { label: r.result, className: "bg-slate-100 text-slate-600" };
              const user = r.userId ? userById.get(r.userId) : undefined;
              return (
                <tr key={r.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-xs text-slate-500">
                    {r.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                  <td className="px-4 py-3 text-slate-700">
                    {r.campaignId ? campaignById.get(r.campaignId) ?? `#${r.campaignId}` : "-"}
                  </td>
                  <td className="px-4 py-3">
                    {user ? (
                      <span className="font-medium text-slate-700">{user.nickname}</span>
                    ) : (
                      <span className="text-slate-400">-</span>
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">
                    {r.couponId ? couponById.get(r.couponId) ?? `#${r.couponId}` : "-"}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${meta.className}`}>
                      {meta.label}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-slate-500">{r.failReason ?? "-"}</td>
                  <td className="px-4 py-3 text-emerald-700">
                    {r.grantedAmount != null ? `${r.grantedAmount.toLocaleString()}개` : "-"}
                  </td>
                  <td className="px-4 py-3 text-slate-600">
                    {r.balanceAfter != null ? `${r.balanceAfter.toLocaleString()}개` : "-"}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-center gap-1">
          {Array.from({ length: totalPages }, (_, i) => i + 1)
            .slice(0, 20)
            .map((p) => (
              <a
                key={p}
                href={`/bokju-coupons/usage?${new URLSearchParams({ ...filterQuery, page: String(p) }).toString()}`}
                className={`rounded-lg px-3 py-1.5 text-sm ${
                  p === page ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-100"
                }`}
              >
                {p}
              </a>
            ))}
        </div>
      )}
    </div>
  );
}
