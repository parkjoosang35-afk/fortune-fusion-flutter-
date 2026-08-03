import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import PageConfigHomeSubNav from "@/components/PageConfigHomeSubNav";

// [메인화면 관리자 편집기] §14-1 대시보드
// 현재 발행버전/임시저장(draft)버전 정보, 활성/숨김/예약 섹션 수, 최근 수정자/발행시각을
// 한눈에 보여준다. 실제 계산 로직은 /api/admin/page-configs/home GET과 동일한 쿼리를
// Server Component에서 직접 prisma로 수행한다(관리자 화면 초기 렌더는 이 프로젝트의
// 일관된 패턴대로 자체 API를 fetch하지 않고 prisma를 직접 사용).
export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export default async function PageConfigHomeDashboard() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const config = await prisma.pageConfig.findUnique({ where: { pageKey: PAGE_KEY } });

  const publishedVersion = config?.currentPublishedVersionId
    ? await prisma.pageVersion.findUnique({ where: { id: config.currentPublishedVersionId } })
    : null;
  const draftVersion = config?.currentDraftVersionId
    ? await prisma.pageVersion.findUnique({ where: { id: config.currentDraftVersionId } })
    : null;

  const draftSections = draftVersion
    ? await prisma.pageSection.findMany({ where: { pageVersionId: draftVersion.id, deletedAt: null } })
    : [];

  const activeCount = draftSections.filter((s) => s.status === "visible").length;
  const hiddenCount = draftSections.filter((s) => s.status === "hidden").length;
  const archivedCount = draftSections.filter((s) => s.status === "archived").length;
  const scheduledCount = draftSections.filter((s) => s.scheduleEnabled).length;

  const lastAudit = await prisma.pageAuditLog.findFirst({
    where: { pageKey: PAGE_KEY },
    orderBy: { createdAt: "desc" },
  });

  const recentLogs = await prisma.pageAuditLog.findMany({
    where: { pageKey: PAGE_KEY },
    orderBy: { createdAt: "desc" },
    take: 8,
  });

  if (!config) {
    return (
      <div>
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-white">메인화면 관리자 편집기</h1>
          <PageConfigHomeSubNav />
        </div>
        <div className="rounded-xl border border-amber-800 bg-amber-950/40 p-6 text-amber-200">
          아직 page_configs(&quot;home&quot;)이 초기화되지 않았습니다. 서버에서{" "}
          <code className="rounded bg-black/30 px-1">npx tsx prisma/seed_page_config_home.ts</code>{" "}
          를 먼저 실행해주세요.
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white">메인화면 관리자 편집기</h1>
            <p className="mt-1 text-sm text-slate-400">
              메인화면 텍스트를 바꾸는 CMS가 아니라, 운영자가 홈 화면 섹션을 안정적으로 조정하고
              발행할 수 있는 &quot;관리자 제어형 홈 화면 블록 편집 시스템&quot;입니다.
            </p>
          </div>
        </div>
        <PageConfigHomeSubNav />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="현재 발행 버전"
          value={publishedVersion ? `v${publishedVersion.versionNumber}` : "없음"}
          hint={publishedVersion?.publishedAt ? new Date(publishedVersion.publishedAt).toLocaleString("ko-KR") : "-"}
          tone="indigo"
        />
        <StatCard
          label="현재 임시저장(draft) 버전"
          value={draftVersion ? `v${draftVersion.versionNumber}` : "없음"}
          hint={draftVersion ? `생성: ${draftVersion.createdBy ?? "-"}` : "-"}
          tone="slate"
        />
        <StatCard label="활성 섹션" value={String(activeCount)} hint={`전체 ${draftSections.length}개 중`} tone="emerald" />
        <StatCard label="예약 노출 섹션" value={String(scheduledCount)} hint={`숨김 ${hiddenCount} / 보관 ${archivedCount}`} tone="amber" />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-5 lg:col-span-2">
          <h2 className="mb-3 text-base font-semibold text-white">최근 변경 로그</h2>
          {recentLogs.length === 0 ? (
            <p className="text-sm text-slate-500">아직 변경 이력이 없습니다.</p>
          ) : (
            <ul className="space-y-2 text-sm">
              {recentLogs.map((log) => (
                <li key={log.id} className="flex items-center justify-between border-b border-slate-800/60 pb-2">
                  <div>
                    <span className="mr-2 rounded bg-slate-800 px-1.5 py-0.5 text-xs text-slate-300">
                      {log.actionType}
                    </span>
                    <span className="text-slate-300">{log.summary}</span>
                  </div>
                  <span className="shrink-0 text-xs text-slate-500">
                    {log.adminId ?? "system"} · {new Date(log.createdAt).toLocaleString("ko-KR")}
                  </span>
                </li>
              ))}
            </ul>
          )}
          <p className="mt-3 text-xs text-slate-500">
            마지막 작업: {lastAudit ? `${lastAudit.actionType} · ${lastAudit.adminId ?? "system"} · ${new Date(lastAudit.createdAt).toLocaleString("ko-KR")}` : "-"}
          </p>
        </div>

        <div className="rounded-xl border border-slate-800 bg-slate-900 p-5">
          <h2 className="mb-3 text-base font-semibold text-white">바로가기</h2>
          <div className="flex flex-col gap-2 text-sm">
            <Link href="/cms/page-configs/home/sections" className="rounded-lg border border-slate-700 px-3 py-2 text-slate-200 hover:bg-slate-800">
              섹션 순서/노출/내용 편집 →
            </Link>
            <Link href="/cms/page-configs/home/publish" className="rounded-lg border border-slate-700 px-3 py-2 text-slate-200 hover:bg-slate-800">
              미리보기 후 발행하기 →
            </Link>
            <Link href="/cms/page-configs/home/versions" className="rounded-lg border border-slate-700 px-3 py-2 text-slate-200 hover:bg-slate-800">
              버전 히스토리 / 롤백 →
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint: string;
  tone: "indigo" | "slate" | "emerald" | "amber";
}) {
  const toneClass = {
    indigo: "text-indigo-400",
    slate: "text-slate-300",
    emerald: "text-emerald-400",
    amber: "text-amber-400",
  }[tone];
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900 p-5">
      <p className="text-xs text-slate-500">{label}</p>
      <p className={`mt-1 text-2xl font-bold ${toneClass}`}>{value}</p>
      <p className="mt-1 text-xs text-slate-500">{hint}</p>
    </div>
  );
}
