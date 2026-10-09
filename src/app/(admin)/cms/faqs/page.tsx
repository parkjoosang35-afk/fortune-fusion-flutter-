import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.8 "CMS" — "FAQ 관리" (04A N-10 faqs CRUD,
// 카테고리/정렬순서). notices 화면 패턴을 재사용한다.
//
// [신통방통 관리자 최종 간소화 실행 지시서 §3 "공지사항·FAQ·이벤트·팝업"]
// notices/events/page.tsx와 동일한 근거로 비노출 처리한다 — Flutter 앱(lib/)
// 전체에 대응 공개 API(/api/public/faqs)를 호출하는 코드가 0건이라 운영자가
// FAQ를 작성해도 회원에게 노출할 경로 자체가 없는 완전히 도달 불가능한
// 화면이었다. CMS 서브탭(banners 등 다른 page.tsx의 <nav>)에서도 이 화면
// 링크를 제거했다. 이 페이지는 접근 시 /cms/banners로 즉시 리다이렉트한다 —
// 서버 액션(actions/faqs.ts)과 Faq Prisma 모델/데이터는 전혀 삭제하지 않는다.
// 원본 UI 코드(FaqCreateForm/FaqRow 렌더링, 카테고리별 정렬 로직)는 git
// 히스토리(이 커밋 이전 버전)에서 그대로 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function CmsFaqsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  redirect("/cms/banners");
}
