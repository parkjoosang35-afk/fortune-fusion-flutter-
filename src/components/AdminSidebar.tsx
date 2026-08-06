"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  Sparkles,
  Gift,
  Store,
  MessageSquare,
  Heart,
  CreditCard,
  FileText,
  Bell,
  ShieldCheck,
  Settings,
  LogOut,
  ExternalLink,
  type LucideIcon,
} from "lucide-react";
import { logout } from "@/app/actions/auth";
import type { AdminMenuGroup } from "@/lib/rbac";

const ICON_MAP: Record<string, LucideIcon> = {
  LayoutDashboard,
  Users,
  Sparkles,
  Gift,
  Store,
  MessageSquare,
  Heart,
  CreditCard,
  FileText,
  Bell,
  ShieldCheck,
  Settings,
};

interface AdminSidebarProps {
  menus: AdminMenuGroup[];
  adminName: string;
  roleCode: string;
  // [9단계 "앱 바로가기"] 사용자 앱(flutter_app) 웹 프리뷰 URL. 미설정 시 버튼 숨김.
  userAppUrl?: string | null;
}

export default function AdminSidebar({
  menus,
  adminName,
  roleCode,
  userAppUrl,
}: AdminSidebarProps) {
  const pathname = usePathname();

  return (
    <aside className="flex h-screen w-60 flex-col border-r border-slate-200 bg-white">
      <div className="border-b border-slate-200 px-4 py-5">
        <p className="text-sm font-bold text-slate-900">Fortune Fusion</p>
        <p className="text-xs text-slate-500">Admin Console</p>
      </div>

      <nav className="flex-1 overflow-y-auto px-2 py-3">
        <ul className="space-y-1">
          {menus.map((menu) => {
            const Icon = ICON_MAP[menu.icon] ?? LayoutDashboard;
            const active =
              pathname === menu.path || pathname.startsWith(menu.path + "/");
            return (
              <li key={menu.code}>
                <Link
                  href={menu.path}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition ${
                    active
                      ? "bg-indigo-600 text-white"
                      : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                  }`}
                >
                  <Icon size={16} />
                  {menu.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* [9단계 "앱 바로가기"] 사용자 앱(flutter_app) 새 탭으로 바로 이동 */}
      {userAppUrl && (
        <div className="border-t border-slate-200 px-2 py-3">
          <a
            href={userAppUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-indigo-600 transition hover:bg-indigo-50"
          >
            <ExternalLink size={16} />
            사용자 앱 바로가기
          </a>
        </div>
      )}

      <div className="border-t border-slate-200 px-4 py-4">
        <p className="truncate text-sm font-medium text-slate-900">{adminName}</p>
        <p className="mb-3 text-xs text-slate-500">{roleCode}</p>
        <form action={logout}>
          <button
            type="submit"
            className="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-500 transition hover:bg-slate-100 hover:text-slate-900"
          >
            <LogOut size={16} />
            로그아웃
          </button>
        </form>
      </div>
    </aside>
  );
}
