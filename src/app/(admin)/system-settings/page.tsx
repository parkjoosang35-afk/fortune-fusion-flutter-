import { redirect } from "next/navigation";
import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu, canDeleteMenu } from "@/lib/rbac";
import SystemSettingCreateForm from "@/components/SystemSettingCreateForm";
import SystemSettingRow from "@/components/SystemSettingRow";

// 05_Admin_System_Design.md §3.11 "시스템 설정" — 1차 소단위: "전역 설정값 관리"
// (04A O-1 system_settings CRUD — 서비스 점검모드 on/off, 최소 앱버전 등)
// 08_Web_Design.md §3.2 라우트 매핑표: 시스템 설정 → /system-settings
export const dynamic = "force-dynamic";

export default async function SystemSettingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "system_settings")) {
    redirect("/dashboard");
  }

  const canWrite = canWriteMenu(session.roleCode, "system_settings");
  const canDelete = canDeleteMenu(session.roleCode, "system_settings");

  const settings = await prisma.systemSetting.findMany({
    where: { deletedAt: null },
    orderBy: { key: "asc" },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">시스템 설정 — 전역 설정값 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          서비스 점검모드 on/off, 최소 앱버전 등 전역 설정값(key-value)을 관리합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link
            href="/system-settings"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            전역 설정값 관리
          </Link>
          <Link href="/system-settings/logs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            접근/에러 로그 조회
          </Link>
          <Link
            href="/system-settings/statistics"
            className="px-3 py-2 text-slate-500 hover:text-slate-900"
          >
            통계 스냅샷 관리
          </Link>
        </nav>
      </div>

      <SystemSettingCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">키(key)</th>
              <th className="px-4 py-3">값(value)</th>
              <th className="px-4 py-3">설명</th>
              <th className="px-4 py-3">최근 수정</th>
              <th className="px-4 py-3">작업</th>
            </tr>
          </thead>
          <tbody>
            {settings.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  등록된 설정값이 없습니다.
                </td>
              </tr>
            )}
            {settings.map((s) => (
              <SystemSettingRow key={s.id} setting={s} canWrite={canWrite} canDelete={canDelete} />
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-2 text-xs text-slate-500">총 설정값 {settings.length}건</p>
    </div>
  );
}
