import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import ReportRow from "@/components/ReportRow";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 3차 소단위: 신고 처리함
// 04A L-6 reports(폴리모픽) 목록/담당자배정/조치(삭제·경고·계정정지)/반려.
// [범위 결정] prisma/schema.prisma의 Report 모델 주석(설계 결정 1~3) 참조.
//   RBAC: 05§5.2에 따라 cs 역할도 write(신고처리 한정) 가능 —
//   actions/reports.ts의 canWriteReports(super_admin/operator/cs)로 판단.
// [08§3.2 라우트] /community/reports는 08 문서에 이미 명시된 라우트이므로
//   신설 근거를 별도로 남길 필요가 없다(1차/2차 소단위의 boards/comments와
//   달리 문서-스펙 시점차 갭이 없음).
// [폴리모픽 조합] target_type(post/comment/wish/user/fortune_result)별로 target_id를
//   그룹핑하여 CommunityPost/Comment/Wish/User/FortuneResult를 배치 조회한 뒤,
//   애플리케이션 레벨에서 각 신고에 대상 라벨을 매핑한다(comments 소단위에서
//   확립한 패턴 재사용). fortune_result는 05§3.2 명시에 따라 추가됨.
export const dynamic = "force-dynamic";

export default async function CommunityReportsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }
  // 05§5.2: cs도 신고처리에 한해 write 가능 — actions/reports.ts의
  // canWriteReports와 동일 로직을 페이지에서도 판단(super_admin/operator/cs).
  const canWrite =
    session.roleCode === "super_admin" || session.roleCode === "operator" || session.roleCode === "cs";

  const reports = await prisma.report.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      reporter: { select: { nickname: true } },
      assignedAdmin: { select: { name: true } },
    },
  });

  const postIds = reports.filter((r) => r.targetType === "post").map((r) => r.targetId);
  const commentIds = reports.filter((r) => r.targetType === "comment").map((r) => r.targetId);
  const wishIds = reports.filter((r) => r.targetType === "wish").map((r) => r.targetId);
  const userIds = reports.filter((r) => r.targetType === "user").map((r) => r.targetId);
  const fortuneResultIds = reports.filter((r) => r.targetType === "fortune_result").map((r) => r.targetId);

  const [posts, comments, wishes, targetUsers, fortuneResults] = await Promise.all([
    postIds.length > 0
      ? prisma.communityPost.findMany({ where: { id: { in: postIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
    commentIds.length > 0
      ? prisma.comment.findMany({ where: { id: { in: commentIds } }, select: { id: true, content: true } })
      : Promise.resolve([]),
    wishIds.length > 0
      ? prisma.wish.findMany({ where: { id: { in: wishIds } }, select: { id: true, content: true } })
      : Promise.resolve([]),
    userIds.length > 0
      ? prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, nickname: true } })
      : Promise.resolve([]),
    fortuneResultIds.length > 0
      ? prisma.fortuneResult.findMany({
          where: { id: { in: fortuneResultIds } },
          select: { id: true, resultText: true },
        })
      : Promise.resolve([]),
  ]);
  const postMap = new Map(posts.map((p) => [p.id, p.title]));
  const commentMap = new Map(comments.map((c) => [c.id, c.content]));
  const wishMap = new Map(wishes.map((w) => [w.id, w.content]));
  const userMap = new Map(targetUsers.map((u) => [u.id, u.nickname]));
  const fortuneResultMap = new Map(fortuneResults.map((f) => [f.id, f.resultText]));

  function truncate(text: string, len: number): string {
    return text.length > len ? text.slice(0, len) + "…" : text;
  }

  function targetLabel(targetType: string, targetId: number): string {
    if (targetType === "post") {
      const title = postMap.get(targetId);
      return title ? truncate(title, 20) : `(삭제된 게시글 #${targetId})`;
    }
    if (targetType === "comment") {
      const content = commentMap.get(targetId);
      return content ? truncate(content, 20) : `(삭제된 댓글 #${targetId})`;
    }
    if (targetType === "wish") {
      const content = wishMap.get(targetId);
      return content ? truncate(content, 20) : `(삭제된 소원 #${targetId})`;
    }
    if (targetType === "user") {
      const nickname = userMap.get(targetId);
      return nickname ?? `(알 수 없는 회원 #${targetId})`;
    }
    if (targetType === "fortune_result") {
      const text = fortuneResultMap.get(targetId);
      return text ? truncate(text, 20) : `(삭제된 운세결과 #${targetId})`;
    }
    return `#${targetId}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">커뮤니티 관리 — 신고 처리함</h1>
        <p className="mt-1 text-sm text-slate-500">
          게시글/댓글/소원/회원 신고를 통합 조회하고 담당자 배정, 조치(삭제·경고·계정정지) 또는 반려 처리를 합니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-200 text-sm">
          <Link href="/community/boards" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            게시판
          </Link>
          <Link href="/community/posts" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            게시글/소원
          </Link>
          <Link href="/community/comments" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            댓글
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">신고</span>
          <Link href="/community/likes" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            좋아요 통계
          </Link>
          <Link href="/community/files" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            파일/업로드
          </Link>
          <Link href="/community/wish-castle" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            🏰 소원성 설정
          </Link>
        </nav>
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">신고 사유</th>
                <th className="px-4 py-3">신고자</th>
                <th className="px-4 py-3">담당자/조치</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">접수일</th>
                <th className="px-4 py-3">처리</th>
              </tr>
            </thead>
            <tbody>
              {reports.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    접수된 신고가 없습니다.
                  </td>
                </tr>
              )}
              {reports.map((r) => (
                <ReportRow
                  key={r.id}
                  report={{
                    id: r.id,
                    targetType: r.targetType,
                    targetLabel: targetLabel(r.targetType, r.targetId),
                    reporterNickname: r.reporter.nickname,
                    reason: r.reason,
                    assignedAdminName: r.assignedAdmin?.name ?? null,
                    action: r.action,
                    status: r.status,
                    createdAt: r.createdAt,
                  }}
                  canWrite={canWrite}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
