import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import FaqCreateForm from "@/components/FaqCreateForm";
import FaqRow from "@/components/FaqRow";

// 05_Admin_System_Design.md §3.8 "CMS" — "FAQ 관리" (04A N-10 faqs CRUD,
// 카테고리/정렬순서). notices 화면 패턴을 재사용한다.
export const dynamic = "force-dynamic";

export default async function CmsFaqsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const faqs = await prisma.faq.findMany({ where: { deletedAt: null } });
  // 카테고리별, 카테고리 내 정렬순서(메모리 정렬 — 복합 orderBy 인덱스 의존 회피 전례 재사용)
  const sorted = [...faqs].sort((a, b) => {
    if (a.category !== b.category) return a.category.localeCompare(b.category);
    return a.sortOrder - b.sortOrder;
  });

  const categories = [...new Set(faqs.map((f) => f.category))];

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — FAQ 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          자주 묻는 질문을 카테고리별로 등록/관리합니다. 정렬 순서로 카테고리 내 노출 순서를
          조정할 수 있습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-400 hover:text-white">
            배너 관리
          </Link>
          <Link href="/cms/popups" className="px-3 py-2 text-slate-400 hover:text-white">
            팝업 관리
          </Link>
          <Link href="/cms/notices" className="px-3 py-2 text-slate-400 hover:text-white">
            공지사항 관리
          </Link>
          <Link
            href="/cms/faqs"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            FAQ 관리
          </Link>
          <Link href="/cms/events" className="px-3 py-2 text-slate-400 hover:text-white">
            이벤트 관리
          </Link>
        </nav>
      </div>

      <FaqCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">카테고리</th>
              <th className="px-4 py-3">질문/답변</th>
              <th className="px-4 py-3">순서</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                  등록된 FAQ가 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((f) => (
              <FaqRow key={f.id} faq={f} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {faqs.length}건 · 카테고리 {categories.length}개
      </p>
    </div>
  );
}
