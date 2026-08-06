import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 4차 소단위: 좋아요 통계
// 04A L-5 likes(폴리모픽) 집계 조회(어뷰징 패턴 탐지용).
// [범위 결정] schema.prisma의 Like 모델 주석 참조: 화면 스펙이 "집계 조회"만
//   명시하므로(CUD 없음), 이번 소단위는 Server Action 없이 순수 읽기 전용
//   페이지만 구현한다(reward/ranking의 "조회 전용" 섹션 패턴과 동일).
// [집계 방식] Prisma groupBy(targetType, targetId)로 대상별 좋아요 수를 집계한
//   뒤, 내림차순 정렬하여 "좋아요가 비정상적으로 몰린 대상"을 상단에 노출한다
//   (어뷰징 패턴 탐지 목적에 직접 부합). 복합 인덱스 요구 없는 단순 groupBy이므로
//   04A/05 문서에서 반복 강조하는 "복잡한 쿼리 인덱스 이슈" 회피 원칙에 부합.
// [폴리모픽 조합] target_type(post/wish/comment)별로 target_id를 그룹핑하여
//   CommunityPost/Wish/Comment를 배치 조회한 뒤, 애플리케이션 레벨에서 각
//   집계 행에 대상 라벨을 매핑한다(comments/reports 소단위에서 확립한 패턴
//   재사용).
export const dynamic = "force-dynamic";

const ABUSE_THRESHOLD = 5; // 임의 기준치: 동일 대상에 대한 좋아요 수가 이 값 이상이면 "주의" 표시

export default async function CommunityLikesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }

  // 대상별(target_type, target_id) 좋아요 수 집계
  const grouped = await prisma.like.groupBy({
    by: ["targetType", "targetId"],
    _count: { _all: true },
  });
  grouped.sort((a, b) => b._count._all - a._count._all);

  const totalLikes = grouped.reduce((sum, g) => sum + g._count._all, 0);

  const postIds = grouped.filter((g) => g.targetType === "post").map((g) => g.targetId);
  const wishIds = grouped.filter((g) => g.targetType === "wish").map((g) => g.targetId);
  const commentIds = grouped.filter((g) => g.targetType === "comment").map((g) => g.targetId);

  const [posts, wishes, comments] = await Promise.all([
    postIds.length > 0
      ? prisma.communityPost.findMany({ where: { id: { in: postIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
    wishIds.length > 0
      ? prisma.wish.findMany({ where: { id: { in: wishIds } }, select: { id: true, content: true } })
      : Promise.resolve([]),
    commentIds.length > 0
      ? prisma.comment.findMany({ where: { id: { in: commentIds } }, select: { id: true, content: true } })
      : Promise.resolve([]),
  ]);
  const postMap = new Map(posts.map((p) => [p.id, p.title]));
  const wishMap = new Map(wishes.map((w) => [w.id, w.content]));
  const commentMap = new Map(comments.map((c) => [c.id, c.content]));

  const TARGET_TYPE_LABEL: Record<string, string> = {
    post: "게시글",
    wish: "소원",
    comment: "댓글",
  };

  function truncate(text: string, len: number): string {
    return text.length > len ? text.slice(0, len) + "…" : text;
  }

  function targetLabel(targetType: string, targetId: number): string {
    if (targetType === "post") {
      const title = postMap.get(targetId);
      return title ? truncate(title, 25) : `(삭제된 게시글 #${targetId})`;
    }
    if (targetType === "wish") {
      const content = wishMap.get(targetId);
      return content ? truncate(content, 25) : `(삭제된 소원 #${targetId})`;
    }
    if (targetType === "comment") {
      const content = commentMap.get(targetId);
      return content ? truncate(content, 25) : `(삭제된 댓글 #${targetId})`;
    }
    return `#${targetId}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">커뮤니티 관리 — 좋아요 통계</h1>
        <p className="mt-1 text-sm text-slate-500">
          게시글/소원/댓글에 대한 좋아요를 대상별로 집계하여 조회합니다(조회 전용).
          좋아요 수가 많은 상위 대상을 우선 노출하여 어뷰징 패턴 탐지에 활용합니다.
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
          <Link href="/community/reports" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            신고
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">좋아요 통계</span>
          <Link href="/community/files" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            파일/업로드
          </Link>
          <Link href="/community/wish-castle" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            🏰 소원성 설정
          </Link>
        </nav>
      </div>

      <section className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">전체 좋아요 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalLikes.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">좋아요 받은 대상 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{grouped.length.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-xs text-slate-500">어뷰징 의심 대상(≥{ABUSE_THRESHOLD}건)</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">
            {grouped.filter((g) => g._count._all >= ABUSE_THRESHOLD).length.toLocaleString()}
          </p>
        </div>
      </section>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">순위</th>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">좋아요 수</th>
                <th className="px-4 py-3">비고</th>
              </tr>
            </thead>
            <tbody>
              {grouped.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 좋아요가 없습니다.
                  </td>
                </tr>
              )}
              {grouped.map((g, idx) => {
                const isAbuse = g._count._all >= ABUSE_THRESHOLD;
                return (
                  <tr
                    key={`${g.targetType}-${g.targetId}`}
                    className={`border-b border-slate-200/60 hover:bg-slate-100/40 ${
                      isAbuse ? "bg-amber-100" : ""
                    }`}
                  >
                    <td className="px-4 py-3 text-slate-500">{idx + 1}</td>
                    <td className="px-4 py-3 text-slate-700">
                      <span className="mr-1 rounded bg-white px-1.5 py-0.5 text-[10px] text-slate-500">
                        {TARGET_TYPE_LABEL[g.targetType] ?? g.targetType}
                      </span>
                      {targetLabel(g.targetType, g.targetId)}
                    </td>
                    <td className="px-4 py-3 font-semibold text-slate-900">{g._count._all}</td>
                    <td className="px-4 py-3">
                      {isAbuse ? (
                        <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                          어뷰징 의심
                        </span>
                      ) : (
                        <span className="text-xs text-slate-600">정상</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
