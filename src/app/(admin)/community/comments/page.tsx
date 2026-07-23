import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canDeleteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import CommentRow from "@/components/CommentRow";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 2차 소단위: 댓글 관리
// 04A L-4 comments(폴리모픽) 목록/삭제.
// [범위 결정] 원칙⑤(소단위 개발): 화면 스펙이 "목록/삭제"만 명시(숨김 기능 없음).
//   댓글 작성은 회원 앱 기능이므로 관리자 화면에서는 제공하지 않는다.
// [폴리모픽 조합] target_type(post/wish)별로 target_id를 그룹핑하여 CommunityPost/
//   Wish를 배치 조회한 뒤, 애플리케이션 레벨에서 각 댓글에 대상 라벨을 매핑한다
//   (Prisma는 폴리모픽 FK를 지원하지 않으므로 include로 join 불가).
// [08§3.2 라우트매핑 보완] 08 문서에는 /community/comments 라우트가 명시되어 있지
//   않으나(게시판관리 때와 동일한 문서-스펙 시점차), 기존 /community/boards 신설
//   전례를 따라 /community/comments로 신설한다.
export const dynamic = "force-dynamic";

export default async function CommunityCommentsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }
  const canDelete = canDeleteMenu(session.roleCode, "community");

  const comments = await prisma.comment.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
    include: { user: { select: { nickname: true } } },
  });

  const postIds = comments.filter((c) => c.targetType === "post").map((c) => c.targetId);
  const wishIds = comments.filter((c) => c.targetType === "wish").map((c) => c.targetId);

  const [posts, wishes] = await Promise.all([
    postIds.length > 0
      ? prisma.communityPost.findMany({ where: { id: { in: postIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
    wishIds.length > 0
      ? prisma.wish.findMany({ where: { id: { in: wishIds } }, select: { id: true, content: true } })
      : Promise.resolve([]),
  ]);
  const postMap = new Map(posts.map((p) => [p.id, p.title]));
  const wishMap = new Map(wishes.map((w) => [w.id, w.content]));

  function targetLabel(targetType: string, targetId: number): string {
    if (targetType === "post") {
      return postMap.get(targetId) ?? `(삭제된 게시글 #${targetId})`;
    }
    if (targetType === "wish") {
      const content = wishMap.get(targetId);
      return content ? content.slice(0, 20) + (content.length > 20 ? "…" : "") : `(삭제된 소원 #${targetId})`;
    }
    return `#${targetId}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">커뮤니티 관리 — 댓글</h1>
        <p className="mt-1 text-sm text-slate-400">
          게시글/소원에 달린 댓글을 조회하고 삭제(Soft Delete) 처리를 합니다.
          작성 기능은 회원 앱에서만 제공됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/community/boards" className="px-3 py-2 text-slate-400 hover:text-white">
            게시판
          </Link>
          <Link href="/community/posts" className="px-3 py-2 text-slate-400 hover:text-white">
            게시글/소원
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">댓글</span>
          <Link href="/community/reports" className="px-3 py-2 text-slate-400 hover:text-white">
            신고
          </Link>
        </nav>
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">댓글 내용</th>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">작성일</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {comments.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 댓글이 없습니다.
                  </td>
                </tr>
              )}
              {comments.map((c) => (
                <CommentRow
                  key={c.id}
                  comment={{
                    id: c.id,
                    targetType: c.targetType,
                    targetLabel: targetLabel(c.targetType, c.targetId),
                    userNickname: c.user.nickname,
                    content: c.content,
                    status: c.status,
                    createdAt: c.createdAt,
                  }}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
