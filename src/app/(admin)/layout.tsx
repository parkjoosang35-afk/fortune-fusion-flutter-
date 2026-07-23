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

  return (
    <div className="flex min-h-screen bg-slate-900">
      <AdminSidebar
        menus={menus}
        adminName={session.name}
        roleCode={session.roleCode}
      />
      <main className="flex-1 overflow-y-auto p-6">{children}</main>
    </div>
  );
}
