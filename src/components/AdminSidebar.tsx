"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
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
  Ticket,
  Megaphone,
  QrCode,
  LogOut,
  ExternalLink,
  ChevronDown,
  ChevronRight,
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
  Ticket,
  Megaphone,
  QrCode,
};

interface AdminSidebarProps {
  menus: AdminMenuGroup[];
  adminName: string;
  roleCode: string;
  // [9단계 "앱 바로가기"] 사용자 앱(flutter_app) 웹 프리뷰 URL. 미설정 시 버튼 숨김.
  userAppUrl?: string | null;
}

// [2026-11-11 관리자 2.0 전면 재설계 - 6메뉴 구조] 그룹에 children이 있으면
// 트리(아코디언)로 렌더링한다. 현재 경로가 그룹의 matchPrefixes/path 중
// 하나라도 매치되면 그 그룹은 기본적으로 펼쳐진 상태로 시작한다(처음 진입 시
// 사용자가 지금 보고 있는 화면이 어느 그룹 소속인지 바로 보이게).
function isGroupActive(menu: AdminMenuGroup, pathname: string): boolean {
  const prefixes = menu.matchPrefixes ?? [menu.path];
  return prefixes.some((p) => pathname === p || pathname.startsWith(p + "/"));
}

export default function AdminSidebar({
  menus,
  adminName,
  roleCode,
  userAppUrl,
}: AdminSidebarProps) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  return (
    <aside className="flex h-screen w-64 flex-col border-r border-slate-200 bg-white">
      <div className="border-b border-slate-200 px-4 py-5">
        <p className="text-sm font-bold text-slate-900">Fortune Fusion</p>
        <p className="text-xs text-slate-500">Admin Console 2.0</p>
      </div>

      <nav className="flex-1 overflow-y-auto px-2 py-3">
        <ul className="space-y-1">
          {menus.map((menu) => {
            const Icon = ICON_MAP[menu.icon] ?? LayoutDashboard;
            const hasChildren = !!menu.children && menu.children.length > 0;
            const groupActive = isGroupActive(menu, pathname);
            // 기본값: 현재 경로와 매치되면 펼침, 아니면 접음. 사용자가 수동으로
            // 토글한 적이 있으면 그 상태(collapsed[menu.code])를 우선한다.
            const isOpen = collapsed[menu.code] !== undefined ? !collapsed[menu.code] : groupActive;

            if (!hasChildren) {
              const active = pathname === menu.path || pathname.startsWith(menu.path + "/");
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
            }

            return (
              <li key={menu.code}>
                <button
                  type="button"
                  onClick={() =>
                    setCollapsed((prev) => ({ ...prev, [menu.code]: isOpen }))
                  }
                  className={`flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left text-sm font-medium transition ${
                    groupActive
                      ? "bg-indigo-50 text-indigo-700"
                      : "text-slate-700 hover:bg-slate-100"
                  }`}
                >
                  <Icon size={16} />
                  <span className="flex-1">{menu.label}</span>
                  {isOpen ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                </button>

                {isOpen && (
                  <ul className="mt-1 space-y-0.5 border-l border-slate-200 pl-4">
                    {menu.children!.map((child, idx) => {
                      const active =
                        pathname === child.path || pathname.startsWith(child.path + "/");
                      return (
                        <li key={`${child.path}-${idx}`}>
                          <Link
                            href={child.path}
                            className={`block rounded-lg px-3 py-1.5 text-xs transition ${
                              active
                                ? "bg-indigo-600 text-white"
                                : "text-slate-500 hover:bg-slate-100 hover:text-slate-900"
                            }`}
                          >
                            {child.label}
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                )}
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
