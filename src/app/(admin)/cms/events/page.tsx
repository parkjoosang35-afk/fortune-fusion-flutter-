import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import EventCreateForm from "@/components/EventCreateForm";
import EventRow from "@/components/EventRow";

// 05_Admin_System_Design.md §3.8 "CMS" — "이벤트 관리" (04A N-5 events,
// N-6 event_participations CRUD 및 참여 현황 조회). 이 화면으로 §3.8
// CMS 5개 화면(배너/팝업/공지사항/FAQ/이벤트)이 모두 완성된다.
export const dynamic = "force-dynamic";

export default async function CmsEventsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;
  const canDelete = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.delete;

  const events = await prisma.event.findMany({ where: { deletedAt: null } });
  // 최신 시작일 우선(메모리 정렬 — 복합 orderBy 인덱스 의존 회피 전례 재사용)
  const sorted = [...events].sort((a, b) => b.startAt.getTime() - a.startAt.getTime());

  // 참여 현황 집계(이벤트별 참여자 수 / 지급완료 수) — event_participations는
  // 조회 전용이므로 페이지 내에서 직접 집계한다.
  const participations = await prisma.eventParticipation.findMany({
    where: { deletedAt: null },
  });
  const statsByEvent = new Map<number, { total: number; claimed: number }>();
  for (const p of participations) {
    const cur = statsByEvent.get(p.eventId) ?? { total: 0, claimed: 0 };
    cur.total += 1;
    if (p.rewardClaimed) cur.claimed += 1;
    statsByEvent.set(p.eventId, cur);
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">CMS — 이벤트 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          출석보너스/룰렛/특별미션 등 이벤트를 타입별 설정(config)으로 등록/관리하고, 참여
          현황(참여자 수/지급완료 수)을 조회합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-400 hover:text-white">
            배너 관리
          </Link>
          <Link href="/cms/notices" className="px-3 py-2 text-slate-400 hover:text-white">
            공지사항 관리
          </Link>
          <Link href="/cms/faqs" className="px-3 py-2 text-slate-400 hover:text-white">
            FAQ 관리
          </Link>
          <Link
            href="/cms/events"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            이벤트 관리
          </Link>
          <Link href="/cms/lucky-number" className="px-3 py-2 text-slate-400 hover:text-white">
            오늘의 행운숫자
          </Link>
          <Link href="/cms/healing-quotes" className="px-3 py-2 text-slate-400 hover:text-white">
            힐링 문구
          </Link>
          <Link href="/cms/page-configs/home" className="px-3 py-2 text-slate-400 hover:text-white">
            메인화면 편집
          </Link>
        </nav>
      </div>

      <EventCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">제목/기간</th>
              <th className="px-4 py-3">타입</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">참여 현황</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  등록된 이벤트가 없습니다.
                </td>
              </tr>
            )}
            {sorted.map((e) => {
              const stats = statsByEvent.get(e.id) ?? { total: 0, claimed: 0 };
              return (
                <EventRow
                  key={e.id}
                  event={e}
                  participationCount={stats.total}
                  claimedCount={stats.claimed}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              );
            })}
          </tbody>
        </table>
      </div>

      <p className="mt-2 text-xs text-slate-500">
        총 {events.length}건 · 전체 참여 {participations.length}건
      </p>
    </div>
  );
}
