import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import AiContentSubNav from "@/components/AiContentSubNav";
import ContentExposureForm from "@/components/ContentExposureForm";
import { getContentOpsItem, EXPOSURE_STATUS_LABEL } from "@/lib/content-ops-meta";
import { DOMAIN_LABEL } from "@/lib/ai-prompt-domain-meta";

// [기획_01_콘텐츠운영_화면설계 §3 화면B] 콘텐츠 상세 관리(탭 5개).
// 9+2개 콘텐츠가 전부 이 템플릿 1개를 공유한다("콘텐츠 1개 = 관리 화면
// 1개" 원칙을 "콘텐츠 1개 = 데이터 1세트 + 공통 템플릿 1개"로 구현 —
// 동일 레이아웃을 9번 복제하지 않고 content-ops-meta.ts의 메타데이터로
// 분기한다).
//
// [탭 구현 범위]
//   ①기본설정 — 개요 텍스트 + 기존 카테고리 노출 설정 화면 링크(새로 안 만듦)
//   ②프롬프트 — 기존 /ai-content/prompts/[domain] 링크 목록(새로 안 만듦),
//     도메인이 없으면 사유(promptNote) 표시
//   ③가격/차감 — 조회 전용(Q3 확정: 금액 편집 기능 없음), 실제 결정 위치 안내
//   ④노출제어 — 이번 작업의 유일한 신규 CUD 기능(ContentOpsConfig)
//   ⑤통계 — AiRequestLog 최근 14일 집계(조회 전용)
export const dynamic = "force-dynamic";

const TABS = [
  { key: "basic", label: "①기본설정" },
  { key: "prompt", label: "②프롬프트" },
  { key: "pricing", label: "③가격/차감" },
  { key: "exposure", label: "④노출제어" },
  { key: "stats", label: "⑤통계" },
];

interface PageProps {
  params: Promise<{ contentKey: string }>;
  searchParams: Promise<{ tab?: string }>;
}

export default async function ContentOpsDetailPage({ params, searchParams }: PageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "ai_content");

  const { contentKey } = await params;
  const item = getContentOpsItem(contentKey);
  if (!item) notFound();

  const sp = await searchParams;
  const activeTab = TABS.some((t) => t.key === sp.tab) ? sp.tab! : "basic";

  const config = await prisma.contentOpsConfig.findUnique({ where: { contentKey } });

  // ── 탭② 프롬프트: 현재 활성 버전 요약(조회만, 편집은 기존 화면에서) ──
  const activeTemplates =
    item.promptDomains.length > 0
      ? await prisma.aiPromptTemplate.findMany({
          where: { fortuneTypeOrDomain: { in: item.promptDomains }, isActive: true },
        })
      : [];
  const activeTemplateMap = new Map(activeTemplates.map((t) => [t.fortuneTypeOrDomain, t]));

  // ── 탭⑤ 통계: 최근 14일 AiRequestLog(연결된 domain들만, 없으면 빈 배열) ──
  const statsDomainCandidates = [contentKey, ...item.promptDomains];
  const fourteenDaysAgo = new Date();
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
  const recentLogs =
    statsDomainCandidates.length > 0
      ? await prisma.aiRequestLog.findMany({
          where: { domain: { in: statsDomainCandidates }, createdAt: { gte: fourteenDaysAgo } },
          orderBy: { createdAt: "desc" },
        })
      : [];
  const totalCalls = recentLogs.length;
  const failedCalls = recentLogs.filter((l) => l.status !== "success").length;
  const recentFailures = recentLogs.filter((l) => l.status !== "success").slice(0, 10);

  function tabHref(tabKey: string) {
    return `/ai-content/overview/${contentKey}?tab=${tabKey}`;
  }

  return (
    <div>
      <div className="mb-4">
        <Link href="/ai-content/overview" className="text-sm text-slate-500 hover:underline">
          ← 콘텐츠 목록으로
        </Link>
        <AiContentSubNav />
      </div>

      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{item.label} 관리</h1>
          <p className="mt-1 text-sm text-slate-500">{item.description}</p>
        </div>
        <span
          className={`rounded-full px-3 py-1 text-xs font-medium ${
            (config?.exposureStatus ?? "visible") === "visible"
              ? "bg-emerald-100 text-emerald-700"
              : (config?.exposureStatus ?? "visible") === "maintenance"
              ? "bg-amber-100 text-amber-700"
              : "bg-white text-slate-500 border border-slate-300"
          }`}
        >
          {EXPOSURE_STATUS_LABEL[config?.exposureStatus ?? "visible"]}
        </span>
      </div>

      <nav className="mb-6 flex flex-wrap gap-1 border-b border-slate-200">
        {TABS.map((tab) => (
          <Link
            key={tab.key}
            href={tabHref(tab.key)}
            className={`rounded-t-lg px-3 py-2 text-sm font-medium transition ${
              activeTab === tab.key
                ? "border-b-2 border-indigo-500 text-slate-900"
                : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}
          </Link>
        ))}
      </nav>

      {activeTab === "basic" && (
        <div className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <div>
            <p className="text-sm text-slate-500">콘텐츠 키</p>
            <p className="font-mono text-sm text-slate-900">{item.contentKey}</p>
          </div>
          <div>
            <p className="text-sm text-slate-500">설명</p>
            <p className="text-sm text-slate-900">{item.description}</p>
          </div>
          {item.categoryKeys.length > 0 && (
            <div>
              <p className="mb-1 text-sm text-slate-500">연결된 운세 카테고리 ({item.categoryKeys.length}개)</p>
              <div className="flex flex-wrap gap-1">
                {item.categoryKeys.map((k) => (
                  <span key={k} className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-700">
                    {DOMAIN_LABEL[k] ?? k}
                  </span>
                ))}
              </div>
            </div>
          )}
          {item.existingAdminLink && (
            <Link
              href={item.existingAdminLink.href}
              className="inline-block rounded-lg border border-indigo-500/60 px-3 py-2 text-sm font-medium text-indigo-700 hover:bg-indigo-100"
            >
              {item.existingAdminLink.label} →
            </Link>
          )}
        </div>
      )}

      {activeTab === "prompt" && (
        <div className="space-y-3">
          {item.promptDomains.length === 0 ? (
            <div className="rounded-xl border border-amber-300 bg-amber-100/60 p-5">
              <p className="text-sm text-amber-700">{item.promptNote ?? "이 콘텐츠는 프롬프트 템플릿을 사용하지 않습니다."}</p>
              {item.existingAdminLink && (
                <Link
                  href={item.existingAdminLink.href}
                  className="mt-3 inline-block text-sm font-medium text-indigo-700 hover:underline"
                >
                  {item.existingAdminLink.label} →
                </Link>
              )}
            </div>
          ) : (
            <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
                  <tr>
                    <th className="px-4 py-3">도메인</th>
                    <th className="px-4 py-3">현재 배포 버전</th>
                    <th className="px-4 py-3"></th>
                  </tr>
                </thead>
                <tbody>
                  {item.promptDomains.map((domain) => {
                    const active = activeTemplateMap.get(domain);
                    return (
                      <tr key={domain} className="border-b border-slate-200/60">
                        <td className="px-4 py-3 text-slate-900">{DOMAIN_LABEL[domain] ?? domain}</td>
                        <td className="px-4 py-3 text-xs">
                          {active ? (
                            <span className="text-emerald-700">v{active.version} 배포중</span>
                          ) : (
                            <span className="text-amber-700">배포된 버전 없음</span>
                          )}
                        </td>
                        <td className="px-4 py-3">
                          <Link
                            href={`/ai-content/prompts/${domain}`}
                            className="text-xs font-medium text-indigo-700 hover:underline"
                          >
                            편집/배포 →
                          </Link>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {activeTab === "pricing" && (
        <div className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <div>
            <p className="text-sm text-slate-500">차감 방식</p>
            <p className="text-base font-medium text-slate-900">{item.pricingMethodLabel}</p>
          </div>
          <div className="rounded-lg bg-slate-100/60 p-3">
            <p className="text-sm text-slate-700">{item.pricingNote}</p>
          </div>
          <p className="text-xs text-slate-500">
            ⚠️ 이 화면에서는 차감 금액/방식을 직접 수정할 수 없습니다(2026-11-11 결정: 당분간
            고정값 유지). 실제 로직 변경이 필요하면 개발팀에 요청해주세요.
          </p>
          <Link
            href="/reward/operation-logs"
            className="inline-block text-sm font-medium text-indigo-700 hover:underline"
          >
            복주머니 거래내역에서 이 콘텐츠 필터링해서 보기 →
          </Link>
        </div>
      )}

      {activeTab === "exposure" && (
        <ContentExposureForm
          contentKey={contentKey}
          currentStatus={config?.exposureStatus ?? "visible"}
          currentNote={config?.maintenanceNote ?? null}
          canWrite={canWrite}
        />
      )}

      {activeTab === "stats" && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-sm text-slate-500">최근 14일 호출 수</p>
              <p className="mt-1 text-2xl font-bold text-slate-900">{totalCalls}</p>
            </div>
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-sm text-slate-500">실패/오류 건수</p>
              <p className="mt-1 text-2xl font-bold text-red-700">{failedCalls}</p>
            </div>
            <div className="rounded-xl border border-slate-200 bg-white p-4">
              <p className="text-sm text-slate-500">실패율</p>
              <p className="mt-1 text-2xl font-bold text-slate-900">
                {totalCalls > 0 ? ((failedCalls / totalCalls) * 100).toFixed(1) : "0.0"}%
              </p>
            </div>
          </div>

          <h3 className="text-sm font-semibold text-slate-700">최근 오류 이력</h3>
          <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">일시</th>
                  <th className="px-4 py-3">도메인</th>
                  <th className="px-4 py-3">상태</th>
                  <th className="px-4 py-3">모델</th>
                </tr>
              </thead>
              <tbody>
                {recentFailures.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-6 text-center text-slate-500">
                      최근 14일간 오류 이력이 없습니다.
                    </td>
                  </tr>
                ) : (
                  recentFailures.map((log) => (
                    <tr key={log.id} className="border-b border-slate-200/60">
                      <td className="px-4 py-3 text-xs text-slate-500">
                        {log.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                      </td>
                      <td className="px-4 py-3 text-slate-700">{log.domain}</td>
                      <td className="px-4 py-3 text-xs text-red-700">{log.status}</td>
                      <td className="px-4 py-3 text-xs text-slate-500">{log.aiModel}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Link href="/ai-content/logs" className="inline-block text-sm font-medium text-indigo-700 hover:underline">
            전체 AI 호출 로그 보기 →
          </Link>
        </div>
      )}
    </div>
  );
}
