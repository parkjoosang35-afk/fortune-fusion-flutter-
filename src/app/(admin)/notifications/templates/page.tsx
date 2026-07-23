import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import NotificationTemplateCreateForm from "@/components/NotificationTemplateCreateForm";
import NotificationTemplateRow from "@/components/NotificationTemplateRow";

// 05_Admin_System_Design.md §3.9 "알림 관리" — "알림 템플릿 관리"
// (04A N-1 notification_templates CRUD, 푸시/인앱 공용 템플릿)
export const dynamic = "force-dynamic";

export default async function NotificationTemplatesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "notifications")) {
    redirect("/dashboard");
  }

  const canWrite =
    !!RBAC_MATRIX.notifications[session.roleCode as keyof typeof RBAC_MATRIX.notifications]
      ?.write;
  const canDelete =
    !!RBAC_MATRIX.notifications[session.roleCode as keyof typeof RBAC_MATRIX.notifications]
      ?.delete;

  const templates = await prisma.notificationTemplate.findMany({ where: { deletedAt: null } });
  const sorted = [...templates].sort((a, b) => a.code.localeCompare(b.code));

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">알림 관리 — 알림 템플릿 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          푸시/인앱 공용 알림 템플릿을 등록/관리합니다. 코드(code)는 발송 시 참조되는 고유
          식별자입니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link
            href="/notifications/templates"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            알림 템플릿 관리
          </Link>
          <Link href="/notifications/history" className="px-3 py-2 text-slate-400 hover:text-white">
            발송 이력 조회
          </Link>
          <Link href="/notifications/segment-send" className="px-3 py-2 text-slate-400 hover:text-white">
            세그먼트 발송
          </Link>
          <Link href="/notifications/settings" className="px-3 py-2 text-slate-400 hover:text-white">
            발송 설정 현황
          </Link>
        </nav>
      </div>

      <NotificationTemplateCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">코드</th>
              <th className="px-4 py-3">제목/본문</th>
              <th className="px-4 py-3">딥링크</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                  등록된 알림 템플릿이 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((t) => (
              <NotificationTemplateRow
                key={t.id}
                template={t}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">총 {templates.length}건</p>
    </div>
  );
}
