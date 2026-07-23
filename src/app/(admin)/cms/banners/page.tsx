import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import BannerCreateForm from "@/components/BannerCreateForm";
import BannerRow from "@/components/BannerRow";

// 05_Admin_System_Design.md §3.8 "CMS" — "배너 관리" (04A N-7 banners CRUD)
// [스코프 결정] 쿠팡파트너스 등 제휴사 광고 배너를 이 화면으로 관리한다.
//   link_url에 제휴 어필리에이트 링크를 입력 — "가장 쉬운 관리 형태" 요청에 따라
//   display_condition(JSON 조건편집기, popups 전용)은 배제하고 position_code/sort_order/
//   start_at/end_at/is_active 만으로 단순 구성. 클릭/노출 통계는 04A banners 스펙에
//   없어 이번 1차 구현에서는 제외한다.
export const dynamic = "force-dynamic";

const POSITION_ORDER = ["home_top", "home_middle", "home_bottom"];

export default async function CmsBannersPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const banners = await prisma.banner.findMany({
    where: { deletedAt: null },
  });

  const sorted = [...banners].sort((a, b) => {
    const posDiff = POSITION_ORDER.indexOf(a.positionCode) - POSITION_ORDER.indexOf(b.positionCode);
    if (posDiff !== 0) return posDiff;
    return a.sortOrder - b.sortOrder;
  });

  const activeCount = banners.filter((b) => b.isActive).length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — 배너 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          쿠팡파트너스 등 제휴사 광고 배너를 등록/관리합니다. 이미지, 제휴 링크(link_url),
          노출 위치·기간·활성 여부를 설정할 수 있습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link
            href="/cms/banners"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
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
        </nav>
      </div>

      <BannerCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">이미지</th>
              <th className="px-4 py-3">제목</th>
              <th className="px-4 py-3">노출 위치</th>
              <th className="px-4 py-3">제휴 링크</th>
              <th className="px-4 py-3">노출 기간</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                  등록된 배너가 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((b) => (
              <BannerRow key={b.id} banner={b} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {banners.length}건 · 활성 {activeCount}건 · 비활성 {banners.length - activeCount}건
      </p>
    </div>
  );
}
