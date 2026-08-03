import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import PageConfigHomeSubNav from "@/components/PageConfigHomeSubNav";
import PageConfigRollbackButton from "@/components/PageConfigRollbackButton";

// [메인화면 관리자 편집기] §14-8 변경로그/버전히스토리
// append-only 구조이므로 과거 published 버전의 PageSection이 그대로 보관되어 있어,
// 이 화면에서 특정 과거 버전을 선택해 즉시 롤백(포인터 전환)할 수 있다.
export const dynamic = "force-dynamic";
const PAGE_KEY = "home";

export default async function PageConfigVersionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;

  const config = await prisma.pageConfig.findUnique({ where: { pageKey: PAGE_KEY } });
  const versions = await prisma.pageVersion.findMany({
    where: { pageKey: PAGE_KEY },
    orderBy: { versionNumber: "desc" },
    include: { _count: { select: { sections: true } } },
  });
  const auditLogs = await prisma.pageAuditLog.findMany({
    where: { pageKey: PAGE_KEY },
    orderBy: { createdAt: "desc" },
    take: 50,
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">변경로그 / 버전 히스토리</h1>
        <PageConfigHomeSubNav />
      </div>

      <div className="mb-6 overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-3 py-3">버전</th>
              <th className="px-3 py-3">상태</th>
              <th className="px-3 py-3">섹션 수</th>
              <th className="px-3 py-3">생성</th>
              <th className="px-3 py-3">발행</th>
              <th className="px-3 py-3">액션</th>
            </tr>
          </thead>
          <tbody>
            {versions.map((v) => (
              <tr key={v.id} className="border-b border-slate-800/60">
                <td className="px-3 py-3 font-medium text-white">
                  v{v.versionNumber}
                  {config?.currentPublishedVersionId === v.id && (
                    <span className="ml-2 rounded bg-emerald-900/60 px-1.5 py-0.5 text-xs text-emerald-300">현재 발행중</span>
                  )}
                  {config?.currentDraftVersionId === v.id && (
                    <span className="ml-2 rounded bg-indigo-900/60 px-1.5 py-0.5 text-xs text-indigo-300">현재 draft</span>
                  )}
                </td>
                <td className="px-3 py-3 text-slate-300">{v.status}</td>
                <td className="px-3 py-3 text-slate-300">{v._count.sections}</td>
                <td className="px-3 py-3 text-xs text-slate-500">
                  {v.createdBy ?? "-"} · {new Date(v.createdAt).toLocaleString("ko-KR")}
                </td>
                <td className="px-3 py-3 text-xs text-slate-500">
                  {v.publishedAt ? `${v.publishedBy ?? "-"} · ${new Date(v.publishedAt).toLocaleString("ko-KR")}` : "-"}
                </td>
                <td className="px-3 py-3">
                  {canWrite && v.status === "published" && config?.currentPublishedVersionId !== v.id && (
                    <PageConfigRollbackButton versionNumber={v.versionNumber} />
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="rounded-xl border border-slate-800 bg-slate-900 p-5">
        <h2 className="mb-3 text-base font-semibold text-white">변경 로그(최근 50건)</h2>
        <ul className="space-y-2 text-sm">
          {auditLogs.map((log) => (
            <li key={log.id} className="flex items-center justify-between border-b border-slate-800/60 pb-2">
              <div>
                <span className="mr-2 rounded bg-slate-800 px-1.5 py-0.5 text-xs text-slate-300">{log.actionType}</span>
                <span className="text-slate-300">{log.summary}</span>
              </div>
              <span className="shrink-0 text-xs text-slate-500">
                {log.adminId ?? "system"} · {new Date(log.createdAt).toLocaleString("ko-KR")}
              </span>
            </li>
          ))}
          {auditLogs.length === 0 && <p className="text-sm text-slate-500">변경 이력이 없습니다.</p>}
        </ul>
      </div>
    </div>
  );
}
