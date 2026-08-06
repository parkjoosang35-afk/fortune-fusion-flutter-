import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import { DOMAIN_LABEL } from "@/lib/ai-prompt-domain-meta";
import FortuneCategoryToggleButton from "@/components/FortuneCategoryToggleButton";
import FortuneCategoryReorderButtons from "@/components/FortuneCategoryReorderButtons";

// [운세 카테고리 확장] 운세 카테고리 마스터 관리
// "전체보기 화면(all_categories_screen.dart)"에 노출되는 카테고리를 그룹별로
// 정렬/노출/추천 여부를 관리한다. 실제 결과 텍스트/버전 관리는 기존
// /ai-content/prompts/[domain] 페이지가 그대로 담당한다(중복 구현 없음).
export const dynamic = "force-dynamic";

export default async function FortuneCategoriesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }
  const canWrite =
    canAccessMenu(session.roleCode, "ai_content") &&
    !!RBAC_MATRIX.ai_content[session.roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;

  const groups = await prisma.fortuneCategoryGroup.findMany({
    where: { deletedAt: null },
    orderBy: { displayOrder: "asc" },
    include: {
      categories: {
        where: { deletedAt: null },
        orderBy: { displayOrder: "asc" },
      },
    },
  });

  const ungrouped = await prisma.fortuneCategory.findMany({
    where: { groupId: null, deletedAt: null },
    orderBy: { displayOrder: "asc" },
  });

  const activeTemplates = await prisma.aiPromptTemplate.findMany({
    where: { isActive: true },
    select: { fortuneTypeOrDomain: true, version: true },
  });
  const liveVersionMap = new Map(activeTemplates.map((t) => [t.fortuneTypeOrDomain, t.version]));

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">운세 카테고리 관리</h1>
          <p className="mt-1 text-sm text-slate-500">
            전체보기(all-categories) 화면에 노출되는 그룹/카테고리의 노출·정렬·추천 여부를
            관리합니다. 결과 텍스트/버전 배포는{" "}
            <Link href="/ai-content/prompts" className="text-indigo-700 hover:underline">
              프롬프트 템플릿 관리
            </Link>
            에서 그대로 처리합니다.
          </p>
        </div>
        <Link
          href="/ai-content/categories/groups"
          className="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-100"
        >
          그룹 관리 →
        </Link>
      </div>

      <div className="space-y-6">
        {groups.map((group) => (
          <section
            key={group.code}
            className="rounded-xl border border-slate-200 bg-white p-5"
          >
            <div className="mb-3 flex items-center gap-2">
              <h2 className="text-base font-semibold text-slate-900">{group.label}</h2>
              <span className="text-xs text-slate-500">({group.categories.length}개)</span>
              {!group.isVisible && (
                <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
                  그룹 숨김
                </span>
              )}
            </div>

            {group.categories.length === 0 ? (
              <p className="text-sm text-slate-500">등록된 카테고리가 없습니다.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-slate-200 text-xs text-slate-500">
                      <th className="py-2 pr-3">순서</th>
                      <th className="py-2 pr-3">카테고리</th>
                      <th className="py-2 pr-3">현재버전</th>
                      <th className="py-2 pr-3">활성</th>
                      <th className="py-2 pr-3">노출</th>
                      <th className="py-2 pr-3">추천</th>
                      <th className="py-2 pr-3">배지</th>
                      <th className="py-2 pr-3">라우트</th>
                      <th className="py-2 pr-3"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200/60">
                    {group.categories.map((c) => (
                      <tr key={c.categoryKey}>
                        <td className="py-2 pr-3">
                          <FortuneCategoryReorderButtons
                            categoryKey={c.categoryKey}
                            canWrite={canWrite}
                          />
                        </td>
                        <td className="py-2 pr-3">
                          <div className="font-medium text-slate-900">{c.title}</div>
                          <div className="text-xs text-slate-500">
                            {DOMAIN_LABEL[c.categoryKey] ?? c.categoryKey}
                          </div>
                        </td>
                        <td className="py-2 pr-3 text-xs text-slate-500">
                          {liveVersionMap.has(c.categoryKey)
                            ? `v${liveVersionMap.get(c.categoryKey)}`
                            : "-"}
                        </td>
                        <td className="py-2 pr-3">
                          <FortuneCategoryToggleButton
                            categoryKey={c.categoryKey}
                            field="isActive"
                            value={c.isActive}
                            canWrite={canWrite}
                            labelOn="활성"
                            labelOff="비활성"
                          />
                        </td>
                        <td className="py-2 pr-3">
                          <FortuneCategoryToggleButton
                            categoryKey={c.categoryKey}
                            field="isVisible"
                            value={c.isVisible}
                            canWrite={canWrite}
                            labelOn="노출"
                            labelOff="숨김"
                          />
                        </td>
                        <td className="py-2 pr-3">
                          <FortuneCategoryToggleButton
                            categoryKey={c.categoryKey}
                            field="isFeatured"
                            value={c.isFeatured}
                            canWrite={canWrite}
                            labelOn="대표"
                            labelOff="일반"
                          />
                        </td>
                        <td className="py-2 pr-3 text-xs text-amber-700">
                          {c.badgeLabel ?? "-"}
                        </td>
                        <td className="py-2 pr-3 font-mono text-xs text-slate-500">
                          {c.route ?? (
                            <span className="text-slate-600">준비중(route 없음)</span>
                          )}
                        </td>
                        <td className="py-2 pr-3">
                          <Link
                            href={`/ai-content/categories/${c.categoryKey}`}
                            className="text-xs text-indigo-700 hover:underline"
                          >
                            편집 →
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        ))}

        {ungrouped.length > 0 && (
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-3 text-base font-semibold text-slate-900">그룹 미지정</h2>
            <div className="space-y-2">
              {ungrouped.map((c) => (
                <div key={c.categoryKey} className="flex items-center justify-between text-sm">
                  <span className="text-slate-900">{c.title}</span>
                  <Link
                    href={`/ai-content/categories/${c.categoryKey}`}
                    className="text-xs text-indigo-700 hover:underline"
                  >
                    편집 →
                  </Link>
                </div>
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
