import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import PageConfigHomeSubNav from "@/components/PageConfigHomeSubNav";
import PageConfigSectionEditor from "@/components/PageConfigSectionEditor";
import { serializeSection } from "@/lib/page-config-helpers";

// [메인화면 관리자 편집기] §14-3 섹션 상세편집
// title/subtitle/description/button/link/badge/style-preset/attachments/conditions/
// schedule/asset-linkage를 한 화면에서 편집한다. 실제 저장은 이미 구현된 admin API
// (content/visibility/schedule/[id]/conditions/attachments)를 클라이언트에서 fetch로 호출.
export const dynamic = "force-dynamic";

export default async function PageConfigSectionDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;

  const { id } = await params;
  const sectionId = Number(id);
  if (!Number.isInteger(sectionId)) notFound();

  const section = await prisma.pageSection.findFirst({
    where: { id: sectionId, deletedAt: null },
    include: { attachments: { orderBy: { displayOrder: "asc" } }, displayRules: true },
  });
  if (!section) notFound();

  return (
    <div>
      <div className="mb-6">
        <div className="flex items-center gap-2">
          <Link href="/cms/page-configs/home/sections" className="text-sm text-slate-400 hover:text-white">
            ← 섹션 리스트
          </Link>
        </div>
        <h1 className="mt-2 text-2xl font-bold text-white">
          섹션 편집: {section.title ?? section.sectionKey}
        </h1>
        <PageConfigHomeSubNav />
      </div>

      <PageConfigSectionEditor section={serializeSection(section)} canWrite={canWrite} />
    </div>
  );
}
