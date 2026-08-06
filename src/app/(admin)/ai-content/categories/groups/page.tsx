import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import FortuneCategoryGroupForm from "@/components/FortuneCategoryGroupForm";

// [운세 카테고리 확장] 그룹(오늘/사주/타로/궁합/얼굴손금/이름테마/상담 등) 관리 페이지.
// 그룹명/설명/정렬순서 수정 + 그룹 노출 토글을 담당한다.
// 카테고리 자체의 노출/정렬/추천 관리는 /ai-content/categories 목록 페이지가 담당하며,
// 결과 텍스트/버전 배포는 기존 /ai-content/prompts 구조를 그대로 재사용한다(중복 없음).
export const dynamic = "force-dynamic";

export default async function FortuneCategoryGroupsPage() {
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
      },
    },
  });

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">운세 그룹 관리</h1>
          <p className="mt-1 text-sm text-slate-500">
            전체보기 화면에 노출되는 그룹의 이름/설명/정렬순서/노출 여부를 관리합니다. 그룹 내
            카테고리 순서 변경은{" "}
            <Link href="/ai-content/categories" className="text-indigo-700 hover:underline">
              카테고리 관리
            </Link>{" "}
            목록에서 처리합니다.
          </p>
        </div>
        <Link
          href="/ai-content/categories"
          className="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-100"
        >
          ← 카테고리 관리로
        </Link>
      </div>

      {groups.length === 0 ? (
        <p className="text-sm text-slate-500">등록된 그룹이 없습니다.</p>
      ) : (
        <div className="space-y-4">
          {groups.map((group) => (
            <FortuneCategoryGroupForm
              key={group.code}
              code={group.code}
              label={group.label}
              description={group.description ?? ""}
              displayOrder={group.displayOrder}
              isVisible={group.isVisible}
              categoryCount={group.categories.length}
              canWrite={canWrite}
            />
          ))}
        </div>
      )}
    </div>
  );
}
