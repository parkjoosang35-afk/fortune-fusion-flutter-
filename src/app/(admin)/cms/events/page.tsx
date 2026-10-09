import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.8 "CMS" — "이벤트 관리" (04A N-5 events,
// N-6 event_participations CRUD 및 참여 현황 조회).
//
// [신통방통 관리자 최종 간소화 실행 지시서 §3 "공지사항·FAQ·이벤트·팝업 비노출"]
// [재확인] Flutter 앱(lib/) 전체에 대응 공개 API(/api/public/events)를 호출하는
// 코드가 0건 — 운영자가 이벤트를 작성해도 회원에게 노출할 경로 자체가 없는
// 완전히 도달 불가능한 CMS였다. popups와 동일한 사유로 비노출 처리한다.
// [메뉴 비노출 — 코드/DB 보존] 원본 UI 구현(폼/테이블)은 제거하되, 서버 액션
// (actions/events.ts)과 Prisma 모델(Event/EventParticipation)은 전혀 건드리지
// 않는다. CMS 서브탭(banners 등 다른 page.tsx의 <nav>)에서도 이 화면 링크를
// 제거했다. 이 페이지는 접근 시 /cms/banners로 즉시 리다이렉트한다. 원본 UI
// 코드는 git 히스토리(이 커밋 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function CmsEventsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  redirect("/cms/banners");
}
