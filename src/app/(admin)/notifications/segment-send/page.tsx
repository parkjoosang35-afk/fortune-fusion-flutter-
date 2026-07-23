import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import SegmentSendForm from "@/components/SegmentSendForm";

// 05_Admin_System_Design.md §3.9 "알림 관리" — 3차 소단위: "세그먼트 발송"
// "전체/조건별(가입일/등급/활동패턴) 발송 실행 화면"
// 관련 04A 테이블: notification_templates(N-1)/notifications(N-2)
// (04A에 전용 테이블이 없으므로 CRUD가 아닌 "실행형" 화면 — actions/segment-send.ts 참고)
export const dynamic = "force-dynamic";

export default async function SegmentSendPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "notifications")) {
    redirect("/dashboard");
  }

  const canWrite =
    !!RBAC_MATRIX.notifications[session.roleCode as keyof typeof RBAC_MATRIX.notifications]
      ?.write;

  const templates = await prisma.notificationTemplate.findMany({
    where: { deletedAt: null },
    select: { id: true, code: true, title: true },
  });
  const sortedTemplates = [...templates].sort((a, b) => a.code.localeCompare(b.code));

  const activeUserCount = await prisma.user.count({
    where: { deletedAt: null, status: "active" },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">알림 관리 — 세그먼트 발송</h1>
        <p className="mt-1 text-sm text-slate-400">
          템플릿을 선택하여 전체 회원 또는 조건(가입일/등급/활동패턴)에 해당하는 회원에게
          알림을 발송합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/notifications/templates" className="px-3 py-2 text-slate-400 hover:text-white">
            알림 템플릿 관리
          </Link>
          <Link href="/notifications/history" className="px-3 py-2 text-slate-400 hover:text-white">
            발송 이력 조회
          </Link>
          <Link
            href="/notifications/segment-send"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            세그먼트 발송
          </Link>
          <Link href="/notifications/settings" className="px-3 py-2 text-slate-400 hover:text-white">
            발송 설정 현황
          </Link>
        </nav>
      </div>

      <SegmentSendForm
        templates={sortedTemplates}
        activeUserCount={activeUserCount}
        canWrite={canWrite}
      />
    </div>
  );
}
