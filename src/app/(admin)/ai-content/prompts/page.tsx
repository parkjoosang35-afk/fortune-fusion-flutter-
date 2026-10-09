import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import { DOMAIN_LABEL, DOMAIN_ORDER } from "@/lib/ai-prompt-domain-meta";
import AiContentSubNav from "@/components/AiContentSubNav";

// 05_Admin_System_Design.md §3.2 "프롬프트 템플릿 목록"
// 기능별(도메인별) 최신 활성 버전 요약 + 버전 개수를 보여주고, 상세(편집/배포)로 진입.
// [task 8 6개콘텐츠관리 허브] 사이드바 최상위에서 진입하는 첫 화면이라 AiContentSubNav를
// 여기에만 표시해도 충분하지만, 사용자가 다른 탭으로 직접 이동한 뒤에도 탭이 보여야
// 하므로(SPA가 아니라 각 page.tsx가 독립 렌더링되므로) 허브에 속한 7개 화면 모두에
// 동일하게 삽입한다(RewardSubNav.tsx가 /reward/* 하위 모든 페이지에 삽입된 것과 동일한 원칙).
export const dynamic = "force-dynamic";

export default async function AiPromptsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const templates = await prisma.aiPromptTemplate.findMany({
    where: { deletedAt: null },
    orderBy: [{ fortuneTypeOrDomain: "asc" }, { version: "desc" }],
  });

  const byDomain = new Map<string, typeof templates>();
  for (const t of templates) {
    const list = byDomain.get(t.fortuneTypeOrDomain) ?? [];
    list.push(t);
    byDomain.set(t.fortuneTypeOrDomain, list);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">6개콘텐츠관리 — 프롬프트 템플릿 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          기능(도메인)별 AI 프롬프트 템플릿의 버전 이력을 관리하고 배포합니다. 새 버전은
          기존 내용을 덮어쓰지 않고 항상 새 버전으로 저장됩니다.
        </p>
        <AiContentSubNav />
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {DOMAIN_ORDER.map((domain) => {
          const list = byDomain.get(domain) ?? [];
          const active = list.find((t) => t.isActive);
          const latest = list[0];
          return (
            <Link
              key={domain}
              href={`/ai-content/prompts/${domain}`}
              className="rounded-xl border border-slate-200 bg-white p-5 transition hover:border-indigo-500/60 hover:bg-slate-100/60"
            >
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-base font-semibold text-slate-900">
                  {DOMAIN_LABEL[domain] ?? domain}
                </h2>
                <span className="rounded-full bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-700">
                  v{latest?.version ?? 0}까지 {list.length}개 버전
                </span>
              </div>
              {active ? (
                <div>
                  <p className="text-xs text-emerald-700">
                    현재 배포중: v{active.version}
                  </p>
                  <p className="mt-1 line-clamp-2 text-sm text-slate-500">
                    {active.templateBody}
                  </p>
                </div>
              ) : (
                <p className="text-sm text-amber-700">
                  배포된(활성) 버전이 없습니다.
                </p>
              )}
            </Link>
          );
        })}
      </div>
    </div>
  );
}
