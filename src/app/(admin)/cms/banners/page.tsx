import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import BannerCreateForm from "@/components/BannerCreateForm";
import BannerRow from "@/components/BannerRow";
import BannerPositionMasterSwitch from "@/components/BannerPositionMasterSwitch";

// 05_Admin_System_Design.md §3.8 "CMS" — "배너 관리" (04A N-7 banners CRUD)
// [스코프 결정] 쿠팡파트너스 등 제휴사 광고 배너를 이 화면으로 관리한다.
//   link_url에 제휴 어필리에이트 링크를 입력 — "가장 쉬운 관리 형태" 요청에 따라
//   display_condition(JSON 조건편집기, popups 전용)은 배제하고 position_code/sort_order/
//   start_at/end_at/is_active 만으로 단순 구성. 클릭/노출 통계는 04A banners 스펙에
//   없어 이번 1차 구현에서는 제외한다.
// [무료 광고형 구조 재정비 §8단계 - 관리자 축소] CMS 하위 탭에서 "팝업 관리"
// (/cms/popups) 링크를 제거한다(원칙: 유지→off, 라우트/Prisma Popup 모델은 보존).
// 사유: Popup에 대응하는 공개 API(/api/public/*popup*)가 전혀 없어 Flutter 앱에서
// 팝업을 표시할 방법이 없는, 관리자만 존재하고 실제로는 도달 불가능한 죽은 CMS 화면.
export const dynamic = "force-dynamic";

const POSITION_ORDER = ["home_top", "home_middle", "home_bottom"];

export default async function CmsBannersPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  // [프리패스 단순화] positionCode='open_pass'(프리패스 광고 전용 배너)는
  // 이 화면이 아니라 /reward/pass-policies(프리패스 설정) 화면 하나에서만
  // 관리한다("하나의 관리 화면에서 운영" 요구사항). 홈 배너 목록에서는 제외.
  const banners = await prisma.banner.findMany({
    where: { deletedAt: null, positionCode: { not: "open_pass" } },
  });

  const sorted = [...banners].sort((a, b) => {
    const posDiff = POSITION_ORDER.indexOf(a.positionCode) - POSITION_ORDER.indexOf(b.positionCode);
    if (posDiff !== 0) return posDiff;
    return a.sortOrder - b.sortOrder;
  });

  const activeCount = banners.filter((b) => b.isActive).length;

  // [운세 앱 개발 프롬프트-Task3] 위치별 마스터 스위치 카드용 집계(전체/활성 건수)
  const positionSummaries = POSITION_ORDER.map((positionCode) => {
    const inPosition = banners.filter((b) => b.positionCode === positionCode);
    return {
      positionCode,
      total: inPosition.length,
      active: inPosition.filter((b) => b.isActive).length,
    };
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">CMS — 배너 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          쿠팡파트너스 등 제휴사 광고 배너를 등록/관리합니다. 이미지, 제휴 링크(link_url),
          노출 위치·기간·활성 여부를 설정할 수 있습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link
            href="/cms/banners"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            배너 관리
          </Link>
          <Link href="/cms/notices" className="px-3 py-2 text-slate-500 hover:text-slate-900">
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
          <Link href="/cms/intro-config" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            인트로 관리
          </Link>
        </nav>
      </div>

      <BannerPositionMasterSwitch summaries={positionSummaries} canWrite={canWrite} />

      <BannerCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
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
