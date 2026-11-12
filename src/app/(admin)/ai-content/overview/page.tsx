import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AiContentSubNav from "@/components/AiContentSubNav";
import { CONTENT_OPS_ITEMS, EXPOSURE_STATUS_LABEL } from "@/lib/content-ops-meta";

// [기획_01_콘텐츠운영_화면설계 §2 화면A] 콘텐츠 목록(랜딩) 화면.
// "콘텐츠 1개 = 관리 화면 1개" 원칙의 진입점 — 9개 라이브 콘텐츠 + 신규
// 2개를 한 표로 보여주고, [관리하기]를 누르면 화면B(탭5개 상세)로 이동한다.
// [중복 구현 금지] 이 화면은 기존 FortuneCategory/AiPromptTemplate 등을
// 다시 만들지 않고, content-ops-meta.ts에 정리된 "어느 콘텐츠가 어떤 기존
// 화면/테이블을 쓰는지" 메타데이터 + 신규 ContentOpsConfig(노출상태)만 조회한다.
export const dynamic = "force-dynamic";

const STATUS_BADGE: Record<string, string> = {
  visible: "bg-emerald-100 text-emerald-700",
  hidden: "bg-white text-slate-500 border border-slate-300",
  maintenance: "bg-amber-100 text-amber-700",
};

export default async function ContentOpsOverviewPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const configs = await prisma.contentOpsConfig.findMany();
  const configMap = new Map(configs.map((c) => [c.contentKey, c]));

  // ── 오늘(KST) 이용건수 — FortuneRequest 기반(공용게이트 콘텐츠만 집계 가능,
  // 나머지는 전용 테이블이 달라 "-"로 표시한다. 조회 전용, 집계 로직 신규
  // 발명 없음 — 기존 fortuneType 값 그대로 사용) ──
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const fortuneCounts = await prisma.fortuneRequest.groupBy({
    by: ["fortuneType"],
    where: { createdAt: { gte: todayStart } },
    _count: { fortuneType: true },
  });
  const fortuneCountMap = new Map(fortuneCounts.map((f) => [f.fortuneType, f._count.fortuneType]));

  const [compatToday, gunghapToday, wishToday] = await Promise.all([
    prisma.compatibilityRequest.count({ where: { createdAt: { gte: todayStart } } }),
    prisma.gunghapPairResult.count({ where: { createdAt: { gte: todayStart } } }),
    prisma.wish.count({ where: { createdAt: { gte: todayStart } } }),
  ]);
  const extraCountMap: Record<string, number> = {
    compatibility: compatToday,
    gunghap: gunghapToday,
    wishroom: wishToday,
  };

  // ── 최근 24시간 오류 이력(AiRequestLog.status='failed') → "주의" 배지 ──
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const failedLogs = await prisma.aiRequestLog.groupBy({
    by: ["domain"],
    where: { createdAt: { gte: oneDayAgo }, status: { not: "success" } },
    _count: { domain: true },
  });
  const failedDomainSet = new Set(failedLogs.map((f) => f.domain));
  // domain(ai_request_logs) ↔ contentKey 매핑(일부만 일치, 나머지는 promptDomains로 역매핑)
  function hasRecentError(item: (typeof CONTENT_OPS_ITEMS)[number]): boolean {
    if (failedDomainSet.has(item.contentKey)) return true;
    return item.promptDomains.some((d) => failedDomainSet.has(d));
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">콘텐츠 운영 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          9개 라이브 콘텐츠 + 신규 서비스 2개를 한 화면에서 관리합니다. [관리하기]를 누르면
          기본설정/프롬프트/가격·차감/노출제어/통계 5개 탭이 있는 상세 화면으로 이동합니다.
        </p>
        <AiContentSubNav />
      </div>

      <h2 className="mb-2 text-sm font-semibold text-slate-700">라이브 콘텐츠 (9개)</h2>
      <div className="mb-8 overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">콘텐츠명</th>
              <th className="px-4 py-3">노출상태</th>
              <th className="px-4 py-3">오늘 이용건수</th>
              <th className="px-4 py-3">차감방식</th>
              <th className="px-4 py-3">프롬프트</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {CONTENT_OPS_ITEMS.filter((i) => i.group === "live").map((item) => {
              const config = configMap.get(item.contentKey);
              const status = config?.exposureStatus ?? "visible";
              const todayCount =
                fortuneCountMap.get(item.contentKey) ?? extraCountMap[item.contentKey] ?? null;
              const badgeClass = hasRecentError(item)
                ? STATUS_BADGE.maintenance
                : STATUS_BADGE[status];
              const badgeLabel = hasRecentError(item) ? "⚠️ 주의" : EXPOSURE_STATUS_LABEL[status];
              return (
                <tr key={item.contentKey} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3">
                    <div className="font-medium text-slate-900">{item.label}</div>
                    <div className="text-xs text-slate-500">{item.description}</div>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${badgeClass}`}>
                      {badgeLabel}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-700">
                    {todayCount != null ? `${todayCount.toLocaleString()}건` : "-"}
                  </td>
                  <td className="px-4 py-3 text-xs text-slate-600">{item.pricingMethodLabel}</td>
                  <td className="px-4 py-3 text-xs text-slate-600">
                    {item.promptDomains.length > 0 ? `${item.promptDomains.length}개 도메인` : "없음"}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/ai-content/overview/${item.contentKey}`}
                      className="text-xs font-medium text-indigo-700 hover:underline"
                    >
                      관리하기 →
                    </Link>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <h2 className="mb-2 text-sm font-semibold text-slate-700">신규 서비스 (기획중, 2개)</h2>
      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">콘텐츠명</th>
              <th className="px-4 py-3">노출상태</th>
              <th className="px-4 py-3">비고</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {CONTENT_OPS_ITEMS.filter((i) => i.group === "new").map((item) => {
              const config = configMap.get(item.contentKey);
              const status = config?.exposureStatus ?? "hidden";
              return (
                <tr key={item.contentKey} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3">
                    <div className="font-medium text-slate-900">{item.label}</div>
                    <div className="text-xs text-slate-500">{item.description}</div>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_BADGE[status]}`}>
                      {EXPOSURE_STATUS_LABEL[status]}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-amber-700">1차 범위 — 미출시</td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/ai-content/overview/${item.contentKey}`}
                      className="text-xs font-medium text-indigo-700 hover:underline"
                    >
                      관리하기 →
                    </Link>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
