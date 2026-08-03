import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import PageConfigHomeSubNav from "@/components/PageConfigHomeSubNav";
import PageConfigSectionRow from "@/components/PageConfigSectionRow";
import PageConfigSectionCreateForm from "@/components/PageConfigSectionCreateForm";

// [메인화면 관리자 편집기] §14-2 섹션 리스트
// 순서/이름/blockType/상태/플랫폼/스케줄/수정일/액션 컬럼. §5 세로 스택형 reorder는
// 좌표 자유배치가 아니라 위/아래 버튼으로 배열 내 위치만 바꾸는 방식으로 구현한다
// (드래그&드롭 UI는 §20 QA 항목의 "반영되는지"가 핵심이므로, 신뢰성이 높은 버튼 방식을
// 우선 채택 — 추후 드래그 라이브러리 도입은 §21 남은 확장 포인트로 분리).
export const dynamic = "force-dynamic";

async function getOrCreateDraftSectionsForDisplay() {
  const config = await prisma.pageConfig.findUnique({ where: { pageKey: "home" } });
  if (!config?.currentDraftVersionId) return { sections: [], versionNumber: null };
  const version = await prisma.pageVersion.findUnique({ where: { id: config.currentDraftVersionId } });
  const sections = await prisma.pageSection.findMany({
    where: { pageVersionId: config.currentDraftVersionId, deletedAt: null },
    include: { attachments: true, displayRules: true },
    orderBy: { sortOrder: "asc" },
  });
  return { sections, versionNumber: version?.versionNumber ?? null };
}

export default async function PageConfigSectionsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;

  const { sections, versionNumber } = await getOrCreateDraftSectionsForDisplay();

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">섹션 리스트</h1>
        <p className="mt-1 text-sm text-slate-400">
          현재 draft {versionNumber ? `(v${versionNumber})` : ""} 기준입니다. 이 화면에서의 변경은
          발행 전까지 실제 앱에 반영되지 않습니다 — &quot;미리보기/발행센터&quot;에서 발행해야
          라이브에 적용됩니다.
        </p>
        <PageConfigHomeSubNav />
      </div>

      <PageConfigSectionCreateForm canWrite={canWrite} nextSortOrder={sections.length} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-3 py-3">순서</th>
              <th className="px-3 py-3">이름 / sectionKey</th>
              <th className="px-3 py-3">블록 타입</th>
              <th className="px-3 py-3">상태</th>
              <th className="px-3 py-3">플랫폼</th>
              <th className="px-3 py-3">스케줄</th>
              <th className="px-3 py-3">수정일</th>
              <th className="px-3 py-3">액션</th>
            </tr>
          </thead>
          <tbody>
            {sections.map((s, index) => (
              <PageConfigSectionRow
                key={s.id}
                section={{
                  id: s.id,
                  sectionKey: s.sectionKey,
                  title: s.title,
                  blockType: s.blockType,
                  status: s.status,
                  isPinned: s.isPinned,
                  isRequired: s.isRequired,
                  scheduleEnabled: s.scheduleEnabled,
                  startAt: s.startAt ? s.startAt.toISOString() : null,
                  endAt: s.endAt ? s.endAt.toISOString() : null,
                  platformTargets: s.platformTargets,
                  updatedAt: s.updatedAt.toISOString(),
                  attachmentCount: s.attachments.length,
                  ruleCount: s.displayRules.length,
                }}
                allSectionIds={sections.map((x) => x.id)}
                index={index}
                isFirst={index === 0}
                isLast={index === sections.length - 1}
                canWrite={canWrite}
              />
            ))}
          </tbody>
        </table>
        {sections.length === 0 && (
          <p className="p-6 text-center text-sm text-slate-500">
            섹션이 없습니다. 위에서 새 섹션을 추가하세요.
          </p>
        )}
      </div>
    </div>
  );
}
