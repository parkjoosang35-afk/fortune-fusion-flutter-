import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { DOMAIN_LABEL } from "@/lib/ai-prompt-domain-meta";
import FortuneCategoryMetaForm from "@/components/FortuneCategoryMetaForm";

// [운세 카테고리 확장] 카테고리 상세 편집 + 현재 배포 버전/버전관리 바로가기.
export const dynamic = "force-dynamic";

interface Props {
  params: Promise<{ categoryKey: string }>;
}

export default async function FortuneCategoryDetailPage({ params }: Props) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite =
    canAccessMenu(session.roleCode, "ai_content") &&
    !!RBAC_MATRIX.ai_content[session.roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;

  const { categoryKey } = await params;
  const category = await prisma.fortuneCategory.findUnique({ where: { categoryKey } });
  if (!category) notFound();

  const groups = await prisma.fortuneCategoryGroup.findMany({
    where: { deletedAt: null },
    orderBy: { displayOrder: "asc" },
    select: { id: true, label: true },
  });

  const versions = await prisma.aiPromptTemplate.findMany({
    where: { fortuneTypeOrDomain: categoryKey, deletedAt: null },
    orderBy: { version: "desc" },
  });
  const activeVersion = versions.find((v) => v.isActive);

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/ai-content/categories" className="text-sm text-slate-400 hover:text-white">
          ← 운세 카테고리 목록
        </Link>
      </div>

      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">
          {category.title}
          <span className="ml-2 text-sm font-normal text-slate-500">
            ({DOMAIN_LABEL[categoryKey] ?? categoryKey})
          </span>
        </h1>
        <Link
          href={`/ai-content/prompts/${categoryKey}`}
          className="rounded-lg border border-indigo-500/60 px-3 py-2 text-sm text-indigo-400 hover:bg-indigo-950/60"
        >
          프롬프트 버전 관리 →
        </Link>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">카테고리 메타 편집</h2>
            <FortuneCategoryMetaForm
              categoryKey={category.categoryKey}
              title={category.title}
              shortDescription={category.shortDescription ?? ""}
              icon={category.icon ?? ""}
              badgeLabel={category.badgeLabel ?? ""}
              route={category.route ?? ""}
              resultLengthHint={category.resultLengthHint ?? ""}
              groups={groups}
              currentGroupId={category.groupId}
              canWrite={canWrite}
            />
          </section>
        </div>

        <div>
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-3 text-sm font-semibold text-white">현재 배포 상태</h2>
            {activeVersion ? (
              <div>
                <p className="text-sm text-emerald-400">현재 배포중: v{activeVersion.version}</p>
                <p className="mt-2 line-clamp-4 text-xs text-slate-500">
                  {activeVersion.templateBody}
                </p>
              </div>
            ) : (
              <p className="text-sm text-amber-400">배포된(활성) 버전이 없습니다.</p>
            )}
            <p className="mt-3 text-xs text-slate-600">
              버전 이력 총 {versions.length}개 · 새 버전 작성/배포전환/롤백은 프롬프트 템플릿
              관리에서 진행합니다.
            </p>
          </section>

          <section className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-5 text-xs text-slate-500">
            <p>
              <strong className="text-slate-300">활성(isActive)</strong>: 전체보기/앱에서 이
              카테고리를 아예 사용 가능한지 여부
            </p>
            <p className="mt-1">
              <strong className="text-slate-300">노출(isVisible)</strong>: 전체보기 화면에 카드로
              보일지 여부(비노출이어도 앱 라우트는 살아있을 수 있음)
            </p>
            <p className="mt-1">
              <strong className="text-slate-300">추천(isFeatured)</strong>: 대표 카테고리 강조
              영역에 우선 노출
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
