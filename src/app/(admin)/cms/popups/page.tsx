import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import PopupCreateForm from "@/components/PopupCreateForm";
import PopupRow from "@/components/PopupRow";

// 05_Admin_System_Design.md §3.8 "CMS" — "팝업 관리" (04A N-8 popups CRUD,
// 노출 조건/1회성·반복 설정). banners 화면(aa0fad2) 패턴을 재사용한다.
export const dynamic = "force-dynamic";

export default async function CmsPopupsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const popups = await prisma.popup.findMany({ where: { deletedAt: null } });
  const sorted = [...popups].sort((a, b) => b.startAt.getTime() - a.startAt.getTime());
  const activeCount = popups.filter((p) => p.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — 팝업 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          앱 진입 시 노출되는 팝업을 등록/관리합니다. 텍스트 전용 팝업도 허용되며, 1회성/반복
          노출 및 대상 세그먼트를 설정할 수 있습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-400 hover:text-white">
            배너 관리
          </Link>
          <Link href="/cms/popups" className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500">
            팝업 관리
          </Link>
          <Link href="/cms/notices" className="px-3 py-2 text-slate-400 hover:text-white">
            공지사항 관리
          </Link>
          <Link href="/cms/faqs" className="px-3 py-2 text-slate-400 hover:text-white">
            FAQ 관리
          </Link>
          <Link href="/cms/events" className="px-3 py-2 text-slate-400 hover:text-white">
            이벤트 관리
          </Link>
        </nav>
      </div>

      <PopupCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">제목/링크</th>
              <th className="px-4 py-3">이미지</th>
              <th className="px-4 py-3">노출 조건</th>
              <th className="px-4 py-3">노출 기간</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                  등록된 팝업이 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((p) => (
              <PopupRow key={p.id} popup={p} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {popups.length}건 · 활성 {activeCount}건 · 비활성 {popups.length - activeCount}건
      </p>
    </div>
  );
}
