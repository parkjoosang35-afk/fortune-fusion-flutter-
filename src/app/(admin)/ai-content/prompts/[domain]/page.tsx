import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import PromptVersionForm from "@/components/PromptVersionForm";
import PromptDeployButton from "@/components/PromptDeployButton";
import { DOMAIN_LABEL } from "@/lib/ai-prompt-domain-meta";

// 05_Admin_System_Design.md §3.2 "템플릿 편집" + 버전 이력 + 배포
// 09_AI_System_Design.md §4: 버전 증가(INSERT-only), 배포는 is_active 토글
export const dynamic = "force-dynamic";

const VALID_DOMAINS = Object.keys(DOMAIN_LABEL);

interface PromptDomainPageProps {
  params: Promise<{ domain: string }>;
}

export default async function PromptDomainPage({ params }: PromptDomainPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const { domain } = await params;
  if (!VALID_DOMAINS.includes(domain)) {
    notFound();
  }

  const versions = await prisma.aiPromptTemplate.findMany({
    where: { fortuneTypeOrDomain: domain, deletedAt: null },
    orderBy: { version: "desc" },
  });

  const activeVersion = versions.find((v) => v.isActive);
  const latestVersion = versions[0];

  const canWrite =
    canAccessMenu(session.roleCode, "ai_content") &&
    !!RBAC_MATRIX.ai_content[session.roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/ai-content/prompts" className="text-sm text-slate-400 hover:text-white">
          ← 프롬프트 템플릿 목록
        </Link>
      </div>

      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">
          {DOMAIN_LABEL[domain]} 프롬프트 템플릿
        </h1>
        <span className="text-sm text-slate-500">
          현재 배포중: {activeVersion ? `v${activeVersion.version}` : "없음"}
        </span>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* 좌측: 새 버전 편집 폼 */}
        <div className="lg:col-span-2">
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">
              새 버전 작성 (기준: v{latestVersion?.version ?? 0})
            </h2>
            <PromptVersionForm
              domain={domain}
              baseTemplateBody={latestVersion?.templateBody ?? ""}
              canWrite={canWrite}
            />
          </section>
        </div>

        {/* 우측: 버전 이력 + 배포 */}
        <div>
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">버전 이력</h2>
            <div className="space-y-3">
              {versions.length === 0 && (
                <p className="text-sm text-slate-500">버전 이력이 없습니다.</p>
              )}
              {versions.map((v) => (
                <div
                  key={v.id}
                  className="rounded-lg border border-slate-800 bg-slate-800/40 p-3"
                >
                  <div className="mb-1 flex items-center justify-between">
                    <span className="text-sm font-medium text-white">v{v.version}</span>
                    <PromptDeployButton
                      domain={domain}
                      templateId={v.id}
                      isActive={v.isActive}
                      canWrite={canWrite}
                    />
                  </div>
                  <p className="line-clamp-3 text-xs text-slate-500">
                    {v.templateBody}
                  </p>
                  <p className="mt-1 text-xs text-slate-600">
                    {v.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                    {v.createdBy ? ` · ${v.createdBy}` : ""}
                  </p>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
