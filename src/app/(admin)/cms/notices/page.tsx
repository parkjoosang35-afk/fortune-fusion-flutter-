import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import NoticeCreateForm from "@/components/NoticeCreateForm";
import NoticeRow from "@/components/NoticeRow";

// 05_Admin_System_Design.md §3.8 "CMS" — "공지사항 관리" (04A N-9 notices CRUD,
// 고정 여부). banners/popups 화면 패턴을 재사용한다.
export const dynamic = "force-dynamic";

export default async function CmsNoticesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const notices = await prisma.notice.findMany({ where: { deletedAt: null } });
  // 고정 우선, 그 다음 최신순 (메모리 정렬 — 복합 orderBy 인덱스 의존 회피 전례 재사용)
  const sorted = [...notices].sort((a, b) => {
    if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1;
    return b.createdAt.getTime() - a.createdAt.getTime();
  });

  const pinnedCount = notices.filter((n) => n.isPinned).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">CMS — 공지사항 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          앱 내 공지사항을 등록/관리합니다. 상단 고정 설정 시 목록 최상단에 항상 노출됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            배너 관리
          </Link>
          <Link
            href="/cms/notices"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            공지사항 관리
          </Link>
          <Link href="/cms/faqs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            FAQ 관리
          </Link>
          <Link href="/cms/events" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            이벤트 관리
          </Link>
          <Link href="/cms/lucky-number" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            오늘의 행운숫자
          </Link>
          <Link href="/cms/healing-quotes" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            힐링 문구
          </Link>
          <Link href="/cms/page-configs/home" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            메인화면 편집
          </Link>
        </nav>
      </div>

      <NoticeCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">제목/내용</th>
              <th className="px-4 py-3">작성일</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                  등록된 공지사항이 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((n) => (
              <NoticeRow key={n.id} notice={n} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {notices.length}건 · 고정 {pinnedCount}건 · 일반 {notices.length - pinnedCount}건
      </p>
    </div>
  );
}
