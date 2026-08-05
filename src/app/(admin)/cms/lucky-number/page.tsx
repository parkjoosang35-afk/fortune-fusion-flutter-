import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import LuckyNumberCreateForm from "@/components/LuckyNumberCreateForm";
import LuckyNumberRow from "@/components/LuckyNumberRow";

// "오늘의 행운숫자" 관리자 콘텐츠 관리 화면.
// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — 이 화면은 banners와
// 완전히 분리된 lucky_number_contents 테이블만 다룬다(단일 슬롯 콘텐츠, position_code 없음).
// RBAC 권한은 기존 CMS 메뉴 코드("cms")를 그대로 재사용해 접근을 통제한다.
export const dynamic = "force-dynamic";

export default async function CmsLuckyNumberPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const contents = await prisma.luckyNumberContent.findMany({
    where: { deletedAt: null },
  });

  const sorted = [...contents].sort((a, b) => a.sortOrder - b.sortOrder);
  const activeCount = contents.filter((c) => c.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — 오늘의 행운숫자 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          홈 화면 &quot;오늘의 행운 숫자&quot; 카드에 노출할 이미지/영상/소스 콘텐츠를 등록·관리합니다.
          이 기능은 광고(배너)와 무관한 별도 콘텐츠입니다. 활성 콘텐츠 중 노출 순서가 가장 낮은
          1건이 앱에 노출됩니다.
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
          <Link href="/cms/faqs" className="px-3 py-2 text-slate-400 hover:text-white">
            FAQ 관리
          </Link>
          <Link href="/cms/events" className="px-3 py-2 text-slate-400 hover:text-white">
            이벤트 관리
          </Link>
          <Link
            href="/cms/lucky-number"
            className="px-3 py-2 font-medium text-white border-b-2 border-purple-500"
          >
            오늘의 행운숫자
          </Link>
          <Link href="/cms/healing-quotes" className="px-3 py-2 text-slate-400 hover:text-white">
            힐링 문구
          </Link>
          <Link href="/cms/page-configs/home" className="px-3 py-2 text-slate-400 hover:text-white">
            메인화면 편집
          </Link>
        </nav>
      </div>

      <LuckyNumberCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">미디어</th>
              <th className="px-4 py-3">제목</th>
              <th className="px-4 py-3">노출 기간</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  등록된 행운숫자 콘텐츠가 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((c) => (
              <LuckyNumberRow key={c.id} content={c} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {contents.length}건 · 활성 {activeCount}건 · 비활성 {contents.length - activeCount}건
      </p>
    </div>
  );
}
