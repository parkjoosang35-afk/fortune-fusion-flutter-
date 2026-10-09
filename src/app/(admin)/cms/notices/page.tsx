import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// 05_Admin_System_Design.md §3.8 "CMS" — "공지사항 관리" (04A N-9 notices CRUD,
// 고정 여부). banners/popups 화면 패턴을 재사용한다.
//
// [신통방통 관리자 최종 간소화 실행 지시서 §3 "공지사항·FAQ·이벤트·팝업"]
// Flutter 앱(lib/) 전체에 대응하는 공개 API(/api/public/notices 등)를 호출하는
// 코드가 0건 — 운영자가 아무리 공지를 작성해도 회원에게 노출할 경로 자체가
// 없는 완전히 도달 불가능한 화면이다(popups와 동일한 사유로 이미 비노출
// 처리된 전례를 그대로 따름). CMS 탭에서 링크를 제거하고 이 페이지 자체도
// /cms/banners로 리다이렉트한다 — 서버액션(actions/notices.ts)/Notice Prisma
// 모델/데이터는 전혀 삭제하지 않는다. 원본 UI 코드는 git 히스토리(이 커밋
// 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function CmsNoticesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  redirect("/cms/banners");
}
