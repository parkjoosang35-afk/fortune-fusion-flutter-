import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.2 "프롬프트 템플릿 목록"
// 기능별(도메인별) 최신 활성 버전 요약 + 버전 개수를 보여주고, 상세(편집/배포)로 진입.
export const dynamic = "force-dynamic";

const DOMAIN_LABEL: Record<string, string> = {
  saju: "사주풀이",
  daily: "오늘의 운세",
  tarot: "타로",
  face: "관상",
  palm: "손금",
  consultation: "AI 상담",
};

const DOMAIN_ORDER = ["saju", "daily", "tarot", "face", "palm", "consultation"];

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
        <h1 className="text-2xl font-bold text-white">프롬프트 템플릿 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          기능(도메인)별 AI 프롬프트 템플릿의 버전 이력을 관리하고 배포합니다. 새 버전은
          기존 내용을 덮어쓰지 않고 항상 새 버전으로 저장됩니다.
        </p>
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
              className="rounded-xl border border-slate-800 bg-slate-900 p-5 transition hover:border-indigo-500/60 hover:bg-slate-800/60"
            >
              <div className="mb-3 flex items-center justify-between">
                <h2 className="text-base font-semibold text-white">
                  {DOMAIN_LABEL[domain] ?? domain}
                </h2>
                <span className="rounded-full bg-indigo-950/60 px-2 py-1 text-xs font-medium text-indigo-400">
                  v{latest?.version ?? 0}까지 {list.length}개 버전
                </span>
              </div>
              {active ? (
                <div>
                  <p className="text-xs text-emerald-400">
                    현재 배포중: v{active.version}
                  </p>
                  <p className="mt-1 line-clamp-2 text-sm text-slate-400">
                    {active.templateBody}
                  </p>
                </div>
              ) : (
                <p className="text-sm text-amber-400">
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
