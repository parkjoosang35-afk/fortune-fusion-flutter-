import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.9 "알림 관리" — "발송 이력 조회"
// (04A N-2 notifications 조회, 수신자/발송상태). 조회 전용 화면이므로
// Server Action(CUD)을 두지 않는다 — "발송상태"는 04A에 별도 status enum
// 컬럼이 없어 is_read(읽음여부)/sent_at(발송시각)으로 표현한다(원칙② 설계충돌 방지).
export const dynamic = "force-dynamic";

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function NotificationHistoryPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "notifications")) {
    redirect("/dashboard");
  }

  const notifications = await prisma.notification.findMany({
    where: { deletedAt: null },
    include: {
      user: { select: { id: true, nickname: true } },
      template: { select: { code: true } },
    },
  });
  // 최신 발송순(메모리 정렬 — 복합 orderBy 인덱스 의존 회피 전례 재사용)
  const sorted = [...notifications].sort((a, b) => b.sentAt.getTime() - a.sentAt.getTime());

  const readCount = notifications.filter((n) => n.isRead).length;
  const unreadCount = notifications.length - readCount;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">알림 관리 — 발송 이력 조회</h1>
        <p className="mt-1 text-sm text-slate-400">
          발송된 알림의 수신자, 발송 템플릿, 발송 시각, 읽음 여부(발송상태)를 조회합니다.
          (조회 전용 — 알림 생성/발송은 세그먼트 발송 화면에서 처리)
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/notifications/templates" className="px-3 py-2 text-slate-400 hover:text-white">
            알림 템플릿 관리
          </Link>
          <Link
            href="/notifications/history"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
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

      <div className="mb-4 flex gap-3 text-sm text-slate-400">
        <span className="rounded-lg border border-slate-800 bg-slate-900 px-3 py-1.5">
          전체 {notifications.length}건
        </span>
        <span className="rounded-lg border border-slate-800 bg-slate-900 px-3 py-1.5">
          읽음 {readCount}건
        </span>
        <span className="rounded-lg border border-slate-800 bg-slate-900 px-3 py-1.5">
          안읽음 {unreadCount}건
        </span>
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">수신자</th>
              <th className="px-4 py-3">제목/본문</th>
              <th className="px-4 py-3">템플릿</th>
              <th className="px-4 py-3">발송상태</th>
              <th className="px-4 py-3">발송시각</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  발송 이력이 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((n) => (
              <tr key={n.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                <td className="px-4 py-3 text-slate-300">{n.user.nickname}</td>
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-200">{n.title}</div>
                  <p className="mt-1 max-w-xl truncate text-xs text-slate-500">{n.body}</p>
                </td>
                <td className="px-4 py-3 text-xs text-slate-500">
                  {n.template?.code ?? <span className="text-slate-600">(템플릿 없음)</span>}
                </td>
                <td className="px-4 py-3">
                  {n.isRead ? (
                    <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
                      읽음
                    </span>
                  ) : (
                    <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
                      안읽음
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 text-xs text-slate-500">{formatDate(n.sentAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">총 {notifications.length}건</p>
    </div>
  );
}
