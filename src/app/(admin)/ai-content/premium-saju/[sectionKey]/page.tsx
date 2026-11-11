import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canDeleteMenu, canWriteMenu } from "@/lib/rbac";
import PremiumSajuVersionForm from "@/components/PremiumSajuVersionForm";
import PremiumSajuDeployButton from "@/components/PremiumSajuDeployButton";
import DeletePremiumSajuSectionButton from "@/components/DeletePremiumSajuSectionButton";

// [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 섹션 상세 — 버전 이력 + 편집 + 배포.
// prompts/[domain]/page.tsx와 동일한 패턴.
export const dynamic = "force-dynamic";

interface PremiumSajuSectionPageProps {
  params: Promise<{ sectionKey: string }>;
}

export default async function PremiumSajuSectionPage({ params }: PremiumSajuSectionPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const { sectionKey } = await params;

  const versions = await prisma.premiumSajuSection.findMany({
    where: { sectionKey, deletedAt: null },
    orderBy: { version: "desc" },
  });

  if (versions.length === 0) {
    notFound();
  }

  const activeVersion = versions.find((v) => v.isActive);
  const latestVersion = versions[0];

  const canWrite = canWriteMenu(session.roleCode, "ai_content");
  const canDelete = canDeleteMenu(session.roleCode, "ai_content");

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/ai-content/premium-saju" className="text-sm text-slate-500 hover:text-slate-900">
          ← 프리미엄 사주 섹션 목록
        </Link>
      </div>

      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-900">
          {latestVersion.sectionLabel} 섹션 프롬프트 템플릿
        </h1>
        <div className="flex items-center gap-3">
          <span className="text-sm text-slate-500">
            현재 배포중: {activeVersion ? `v${activeVersion.version}` : "없음"}
          </span>
          {canDelete && <DeletePremiumSajuSectionButton sectionKey={sectionKey} />}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">
              새 버전 작성 (기준: v{latestVersion.version})
            </h2>
            <PremiumSajuVersionForm
              sectionKey={sectionKey}
              baseTemplateBody={latestVersion.templateBody}
              canWrite={canWrite}
            />
          </section>
        </div>

        <div>
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">버전 이력</h2>
            <div className="space-y-3">
              {versions.map((v) => (
                <div key={v.id} className="rounded-lg border border-slate-200 bg-white/40 p-3">
                  <div className="mb-1 flex items-center justify-between">
                    <span className="text-sm font-medium text-slate-900">v{v.version}</span>
                    <PremiumSajuDeployButton
                      sectionKey={sectionKey}
                      templateId={v.id}
                      isActive={v.isActive}
                      canWrite={canWrite}
                    />
                  </div>
                  <p className="line-clamp-3 text-xs text-slate-500">{v.templateBody}</p>
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
