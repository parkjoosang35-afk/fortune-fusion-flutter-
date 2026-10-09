import { redirect } from "next/navigation";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";

// [신통방통 관리자 통합 간소화 실행 지시서 task 10 "운영/보안+시스템설정 최소
// 메뉴로 통합"] 사이드바에 신설된 "운영·시스템관리"(ops_system) 단일 진입점의
// 랜딩 라우트. 실제 ops_security/system_settings 권한 체계는 그대로 두고
// (rbac.ts 주석 참고), 역할에 따라 먼저 접근 가능한 화면으로 즉시
// 리다이렉트만 한다:
//   - ops_security 접근 가능(super_admin) → /admin-users (관리자 계정 관리)
//   - ops_security 불가·system_settings 접근 가능(operator) → /system-settings
//   - 둘 다 불가(cs/content_manager) → /dashboard
// 이 페이지 자체는 UI를 렌더링하지 않는다(순수 리다이렉트 허브).
export const dynamic = "force-dynamic";

export default async function OpsSystemLandingPage() {
  const session = await verifyAdminSession();

  if (canAccessMenu(session.roleCode, "ops_security")) {
    redirect("/admin-users");
  }
  if (canAccessMenu(session.roleCode, "system_settings")) {
    redirect("/system-settings");
  }
  redirect("/dashboard");
}
