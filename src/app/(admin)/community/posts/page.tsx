import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import CommunityPostRow from "@/components/CommunityPostRow";
import WishRow from "@/components/WishRow";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 1차 소단위(도메인 L 1단계): 게시글/소원 관리
// 04A L-2 community_posts + L-3 wishes 목록/숨김/삭제(Soft Delete).
// [범위 결정] 원칙⑤(소단위 개발): 게시글/소원 "작성"은 회원 앱 기능이므로 관리자
//   화면에서는 제공하지 않는다. 목록 조회 + 상태변경(노출/숨김/삭제)까지만 다룬다.
//   댓글수/좋아요수는 04A 명시상 캐시(비정규화) 컬럼이며, 실제 갱신 로직은
//   댓글관리(L-4)/좋아요통계(L-5) 소단위에서 구현할 예정이라 이번 단계에서는
//   시딩된 값을 그대로 표시만 한다.
// [08§3.2 라우트매핑] /community/posts는 이미 08 문서에 명시되어 있어 그대로 사용.
//   wishes는 05§3.5에서 community_posts와 같은 화면("게시글/소원 관리")으로 묶여
//   있으므로 같은 페이지 내 별도 섹션(탭 없이 스크롤 구분)으로 구현한다.
export const dynamic = "force-dynamic";

export default async function CommunityPostsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }

  const menuWrite = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.write;
  const canWrite = menuWrite && session.roleCode !== "cs";
  const canDelete = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.delete;

  const posts = await prisma.communityPost.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      board: { select: { name: true } },
      user: { select: { nickname: true } },
    },
  });

  const wishes = await prisma.wish.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
    include: { user: { select: { nickname: true } } },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">커뮤니티 관리 — 게시글/소원</h1>
        <p className="mt-1 text-sm text-slate-400">
          게시글과 소원을 조회하고 노출/숨김/삭제(Soft Delete) 처리를 합니다.
          작성 기능은 회원 앱에서만 제공됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/community/boards" className="px-3 py-2 text-slate-400 hover:text-white">
            게시판
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">게시글/소원</span>
          <Link href="/community/comments" className="px-3 py-2 text-slate-400 hover:text-white">
            댓글
          </Link>
          <Link href="/community/reports" className="px-3 py-2 text-slate-400 hover:text-white">
            신고
          </Link>
          <Link href="/community/likes" className="px-3 py-2 text-slate-400 hover:text-white">
            좋아요 통계
          </Link>
          <Link href="/community/files" className="px-3 py-2 text-slate-400 hover:text-white">
            파일/업로드
          </Link>
        </nav>
      </div>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">게시글 (최근 50건)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">게시판</th>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">반응</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">작성일</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {posts.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 게시글이 없습니다.
                  </td>
                </tr>
              )}
              {posts.map((p) => (
                <CommunityPostRow
                  key={p.id}
                  post={{
                    id: p.id,
                    boardName: p.board.name,
                    userNickname: p.user.nickname,
                    title: p.title,
                    status: p.status,
                    isPinned: p.isPinned,
                    likeCount: p.likeCount,
                    commentCount: p.commentCount,
                    createdAt: p.createdAt,
                  }}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold text-white">소원 (최근 50건)</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">분류</th>
                <th className="px-4 py-3">내용</th>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">응원</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">작성일</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {wishes.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 소원이 없습니다.
                  </td>
                </tr>
              )}
              {wishes.map((w) => (
                <WishRow
                  key={w.id}
                  wish={{
                    id: w.id,
                    userNickname: w.user.nickname,
                    content: w.content,
                    category: w.category,
                    isAnonymous: w.isAnonymous,
                    status: w.status,
                    supportCount: w.supportCount,
                    createdAt: w.createdAt,
                  }}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          익명(is_anonymous) 소원은 작성자 닉네임 대신 &ldquo;익명&rdquo;으로 표시됩니다
          (관리자 조치 시에는 내부적으로 작성자 정보가 유지됩니다).
        </p>
      </section>
    </div>
  );
}
