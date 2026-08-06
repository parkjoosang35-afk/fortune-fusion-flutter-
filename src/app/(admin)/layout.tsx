import { verifyAdminSession } from "@/lib/dal";
import { getVisibleMenusForRole } from "@/lib/rbac";
import AdminSidebar from "@/components/AdminSidebar";

// 대시보드 이하 전체 레이아웃 — RBAC 기반 사이드바 메뉴 필터링
// 05_Admin_System_Design.md §5.2 매트릭스에 따라 역할별로 보이는 메뉴가 다름
export default async function DashboardGroupLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await verifyAdminSession();
  const menus = getVisibleMenusForRole(session.roleCode);
  // [9단계 "앱 바로가기"] 사용자 앱(flutter_app) 웹 프리뷰로 이동하는 링크 URL.
  // 미설정 시(운영 배포 등) 사이드바에서 해당 버튼 자체를 숨긴다.
  const userAppUrl = process.env.NEXT_PUBLIC_USER_APP_URL || null;

  return (
    <div className="flex min-h-screen bg-white">
      <AdminSidebar
        menus={menus}
        adminName={session.name}
        roleCode={session.roleCode}
        userAppUrl={userAppUrl}
      />
      <main className="flex-1 overflow-y-auto p-6">{children}</main>
    </div>
  );
}
