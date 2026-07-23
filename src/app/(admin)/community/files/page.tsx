import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canDeleteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import FileRow from "@/components/FileRow";

// 05_Admin_System_Design.md §3.5 "커뮤니티 관리" — 5차(마지막) 소단위: 파일/업로드 관리
// 04A L-7 files(폴리모픽 공용) 목록 조회 + 문제 이미지 삭제.
// [범위 결정] schema.prisma의 File 모델 주석(설계 결정 1~3) 참조: 05§3.5 스펙이
//   "조회, 문제 이미지 삭제"만 명시하므로 comments.ts(L-4)와 동일하게 상태값
//   2단계(active/deleted_by_admin)만 다루며, RBAC도 canDeleteMenu 기준(super_admin
//   만 write 가능)으로 판단한다(신고 처리함과 달리 cs 예외 없음).
// [폴리모픽 조합] owner_type(user_profile/community_post/amulet_item/banner)별로
//   owner_id를 그룹핑하여 User(profile)/CommunityPost/AmuletItem/Banner를
//   배치 조회한 뒤, 애플리케이션 레벨에서 각 파일에 대상 라벨을 매핑한다
//   (comments/reports/likes 소단위에서 확립한 패턴 재사용).
export const dynamic = "force-dynamic";

export default async function CommunityFilesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }
  const canDelete = canDeleteMenu(session.roleCode, "community");

  const files = await prisma.file.findMany({
    orderBy: { createdAt: "desc" },
    take: 50,
  });

  const profileOwnerIds = files.filter((f) => f.ownerType === "user_profile" && f.ownerId !== null).map((f) => f.ownerId as number);
  const postOwnerIds = files.filter((f) => f.ownerType === "community_post" && f.ownerId !== null).map((f) => f.ownerId as number);
  const amuletOwnerIds = files.filter((f) => f.ownerType === "amulet_item" && f.ownerId !== null).map((f) => f.ownerId as number);
  const bannerOwnerIds = files.filter((f) => f.ownerType === "banner" && f.ownerId !== null).map((f) => f.ownerId as number);

  const [profileUsers, posts, amulets, banners] = await Promise.all([
    profileOwnerIds.length > 0
      ? prisma.user.findMany({ where: { id: { in: profileOwnerIds } }, select: { id: true, nickname: true } })
      : Promise.resolve([]),
    postOwnerIds.length > 0
      ? prisma.communityPost.findMany({ where: { id: { in: postOwnerIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
    amuletOwnerIds.length > 0
      ? prisma.amuletItem.findMany({ where: { id: { in: amuletOwnerIds } }, select: { id: true, name: true } })
      : Promise.resolve([]),
    bannerOwnerIds.length > 0
      ? prisma.banner.findMany({ where: { id: { in: bannerOwnerIds } }, select: { id: true, title: true } })
      : Promise.resolve([]),
  ]);
  const profileMap = new Map(profileUsers.map((u) => [u.id, u.nickname]));
  const postMap = new Map(posts.map((p) => [p.id, p.title]));
  const amuletMap = new Map(amulets.map((a) => [a.id, a.name]));
  const bannerMap = new Map(banners.map((b) => [b.id, b.title]));

  function truncate(text: string, len: number): string {
    return text.length > len ? text.slice(0, len) + "…" : text;
  }

  function ownerLabel(ownerType: string, ownerId: number | null): string {
    if (ownerId === null) {
      return "미연결";
    }
    if (ownerType === "user_profile") {
      const nickname = profileMap.get(ownerId);
      return nickname ?? `(알 수 없는 회원 #${ownerId})`;
    }
    if (ownerType === "community_post") {
      const title = postMap.get(ownerId);
      return title ? truncate(title, 20) : `(삭제된 게시글 #${ownerId})`;
    }
    if (ownerType === "amulet_item") {
      const name = amuletMap.get(ownerId);
      return name ?? `(알 수 없는 부적 #${ownerId})`;
    }
    if (ownerType === "banner") {
      const title = bannerMap.get(ownerId);
      return title ?? `(알 수 없는 배너 #${ownerId})`;
    }
    return `#${ownerId}`;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">커뮤니티 관리 — 파일/업로드 관리</h1>
        <p className="mt-1 text-sm text-slate-400">
          프로필/게시글/부적/배너에 첨부된 파일을 통합 조회하고, 문제 이미지를 삭제(Soft Delete) 처리합니다.
          업로드 기능은 회원 앱/각 도메인 화면에서만 제공됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/community/boards" className="px-3 py-2 text-slate-400 hover:text-white">
            게시판
          </Link>
          <Link href="/community/posts" className="px-3 py-2 text-slate-400 hover:text-white">
            게시글/소원
          </Link>
          <Link href="/community/comments" className="px-3 py-2 text-slate-400 hover:text-white">
            댓글
          </Link>
          <Link href="/community/reports" className="px-3 py-2 text-slate-400 hover:text-white">
            신고
          </Link>
          <Link href="/community/likes" className="px-3 py-2 text-slate-400 hover:text-white">
            좋아요 통계
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">파일/업로드</span>
        </nav>
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">대상</th>
                <th className="px-4 py-3">파일 URL</th>
                <th className="px-4 py-3">유형</th>
                <th className="px-4 py-3">크기</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">업로드일</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {files.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 파일이 없습니다.
                  </td>
                </tr>
              )}
              {files.map((f) => (
                <FileRow
                  key={f.id}
                  file={{
                    id: f.id,
                    ownerType: f.ownerType,
                    ownerLabel: ownerLabel(f.ownerType, f.ownerId),
                    fileUrl: f.fileUrl,
                    fileType: f.fileType,
                    size: f.size,
                    status: f.status,
                    createdAt: f.createdAt,
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
