import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "CMS"]
// notices/faqs/events/page.tsx와 동일한 사유 — Popup에 대응하는 공개 API
// (/api/public/*popup*)가 전혀 없어 Flutter 앱에서 팝업을 표시할 방법이
// 없는, 관리자만 존재하고 실제로는 도달 불가능한 CMS 화면이다. banners
// 서브탭에서는 이미 링크가 제거되어 있었으나 페이지 자체는 URL 직접
// 입력으로 여전히 접근 가능한 고립 상태였다. 접근 시 /cms/banners로
// 리다이렉트한다. 서버 액션(actions/popups.ts)과 Popup Prisma 모델/데이터는
// 전혀 삭제하지 않는다. 원본 UI 코드는 git 히스토리(이 커밋 이전 버전)에서
// 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function CmsPopupsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  redirect("/cms/banners");
}
