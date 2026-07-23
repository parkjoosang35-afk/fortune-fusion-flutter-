import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import CommunityBoardCreateForm from "@/components/CommunityBoardCreateForm";
import CommunityBoardRow from "@/components/CommunityBoardRow";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 1차 소단위(도메인 L 1단계): 게시판 관리
// 04A L-1 community_boards CRUD(게시판 종류/공개설정).
// [범위 결정] 원칙⑤(소단위 개발): community_boards 마스터 CRUD까지 이번 소단위에서
//   다룬다. 게시글/소원 관리(community_posts, wishes)는 /community/posts 페이지에서
//   함께 구현(같은 1차 소단위, 별도 라우트).
// [08§3.2 라우트매핑 보완] 08_Web_Design.md의 커뮤니티 관리 라우트 목록에는
//   /community/posts, /community/reports만 명시되어 있으나(05 문서의 "게시판 관리"
//   화면 항목 반영 이전 버전으로 추정), 기존 /shop/{...}, /reward/{...} 명명 규칙을
//   따라 /community/boards로 신설한다.
// [RBAC] 05§5.2: 커뮤니티 관리 cs 역할은 "신고처리"에만 write 권한이 있으므로,
//   게시판 관리에서는 super_admin/operator만 write 가능(community.ts의
//   canWriteCommunity에서 cs 제외 처리).
export const dynamic = "force-dynamic";

export default async function CommunityBoardsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }

  const menuWrite = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.write;
  const canWrite = menuWrite && session.roleCode !== "cs";
  const canDelete = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.delete;

  const boards = await prisma.communityBoard.findMany({
    where: { deletedAt: null },
    orderBy: { sortOrder: "asc" },
    include: { _count: { select: { posts: { where: { deletedAt: null } } } } },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">커뮤니티 관리 — 게시판</h1>
        <p className="mt-1 text-sm text-slate-400">
          게시판 종류를 등록/관리하고 공개 여부를 설정합니다. 게시글이 존재하는
          게시판은 삭제할 수 없습니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">게시판</span>
          <Link href="/community/posts" className="px-3 py-2 text-slate-400 hover:text-white">
            게시글/소원
          </Link>
          <Link href="/community/comments" className="px-3 py-2 text-slate-400 hover:text-white">
            댓글
          </Link>
        </nav>
      </div>

      <section>
        <CommunityBoardCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">코드</th>
                <th className="px-4 py-3">이름</th>
                <th className="px-4 py-3">설명</th>
                <th className="px-4 py-3">게시글 수</th>
                <th className="px-4 py-3">공개설정</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {boards.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 게시판이 없습니다.
                  </td>
                </tr>
              )}
              {boards.map((b) => (
                <CommunityBoardRow
                  key={b.id}
                  board={{
                    id: b.id,
                    code: b.code,
                    name: b.name,
                    description: b.description,
                    sortOrder: b.sortOrder,
                    isPublic: b.isPublic,
                    postCount: b._count.posts,
                  }}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          04A L-1 명시: code는 UQ 제약이 있어 등록 후 수정할 수 없습니다.
        </p>
      </section>
    </div>
  );
}
