import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import HealingQuoteCreateForm from "@/components/HealingQuoteCreateForm";
import HealingQuoteRow from "@/components/HealingQuoteRow";

// "힐링 문구" 관리자 콘텐츠 관리 화면.
// [사용자 요청] 홈 화면의 "오늘의 운세 이야기"(운세 기능)를 완전히 삭제하고 좋은 글귀/힐링 문구/
// 긍정 명언/응원의 한마디로 대체한다. 이 화면은 lucky-number CMS 화면 구조를 따르되,
// 단일 슬롯이 아니라 "활성 문구 전체"가 앱에서 1분마다 순환 노출된다.
export const dynamic = "force-dynamic";

export default async function CmsHealingQuotesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const quotes = await prisma.healingQuote.findMany({
    where: { deletedAt: null },
  });

  const sorted = [...quotes].sort((a, b) => a.sortOrder - b.sortOrder);
  const activeCount = quotes.filter((q) => q.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — 힐링 문구 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          홈 화면 상단 카드에 노출할 좋은 글귀/힐링 문구/긍정 명언/응원의 한마디를 등록·관리합니다.
          운세·광고와 무관한 별도 콘텐츠이며, 활성 문구 전체가 앱에서 1분마다 순환 노출됩니다.
        </p>
        <nav className="mt-4 flex flex-wrap gap-2 border-b border-slate-800 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-400 hover:text-white">
            배너 관리
          </Link>
          <Link href="/cms/popups" className="px-3 py-2 text-slate-400 hover:text-white">
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
          <Link href="/cms/lucky-number" className="px-3 py-2 text-slate-400 hover:text-white">
            오늘의 행운숫자
          </Link>
          <Link
            href="/cms/healing-quotes"
            className="px-3 py-2 font-medium text-white border-b-2 border-purple-500"
          >
            힐링 문구
          </Link>
          <Link href="/cms/page-configs/home" className="px-3 py-2 text-slate-400 hover:text-white">
            메인화면 편집
          </Link>
        </nav>
      </div>

      <HealingQuoteCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">문구</th>
              <th className="px-4 py-3">분류</th>
              <th className="px-4 py-3">노출 기간</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  등록된 힐링 문구가 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((q) => (
              <HealingQuoteRow key={q.id} quote={q} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {quotes.length}건 · 활성 {activeCount}건 · 비활성 {quotes.length - activeCount}건
      </p>
    </div>
  );
}
