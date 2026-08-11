import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import WishRoomConfigForm from "@/components/WishRoomConfigForm";
import { WISH_ROOM_CONFIG_KEYS } from "@/lib/wish-room-config-meta";

// [소원방(Wish Room) CMS] 커뮤니티 관리 탭 — 소원방 정책(최대 소원 개수/힘주기
// 한도/에너지 증감량/감쇠량/애니메이션 ON-OFF)을 관리자가 즉시 반영할 수 있도록
// 한다. RBAC는 소원성(Wish Castle) CMS와 동일하게 기존 community 매트릭스를
// 그대로 재사용한다(신규 권한 항목 추가 없음 — 기존 시스템 미침해 원칙).
export const dynamic = "force-dynamic";

export default async function WishRoomAdminPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }

  const menuWrite = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.write;
  const canWrite = menuWrite && session.roleCode !== "cs";

  const configRows = await prisma.wishRoomConfig.findMany({
    where: { key: { in: WISH_ROOM_CONFIG_KEYS.map((k) => k.key) } },
  });
  const configViewRows = configRows.map((r) => ({
    key: r.key,
    value: r.value,
    updatedAt: r.updatedAt.toISOString(),
    updatedBy: r.updatedBy,
  }));

  // 운영 현황 요약 — 간단한 카운트 위주(과설계 방지, 상세 통계 대시보드는 범위 밖).
  const [
    activeProfileCount,
    activeWishCount,
    publicWishCount,
    activeCategoryCount,
    themeCount,
    objectCount,
  ] = await Promise.all([
    prisma.wishRoomProfile.count(),
    prisma.wishRoomWish.count({ where: { status: "active" } }),
    prisma.wishRoomWish.count({ where: { status: "active", isPublic: true } }),
    prisma.wishRoomCategory.count({ where: { isActive: true, deletedAt: null } }),
    prisma.wishRoomTheme.count({ where: { isActive: true, deletedAt: null } }),
    prisma.wishRoomObject.count({ where: { isActive: true, deletedAt: null } }),
  ]);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">커뮤니티 관리 — 🏮 소원방 설정</h1>
        <p className="mt-1 text-sm text-slate-500">
          소원방(Wish Room)의 소원 개수 한도, 힘주기(돌보기) 정책, 에너지 증감량,
          미접속 감쇠 규칙, 애니메이션 ON/OFF를 관리합니다. 저장 즉시 앱 API에 반영됩니다.
        </p>
        <nav className="mt-4 flex flex-wrap gap-2 border-b border-slate-200 text-sm">
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
          <Link href="/community/likes" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            좋아요 통계
          </Link>
          <Link href="/community/files" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            파일/업로드
          </Link>
          <Link href="/community/wish-castle" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            소원성 설정
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">소원방 설정</span>
        </nav>
      </div>

      {/* 운영 현황 요약 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">운영 현황 요약</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {[
            { label: "소원방 이용자", value: activeProfileCount, unit: "명" },
            { label: "활성 소원", value: activeWishCount, unit: "개" },
            { label: "공개된 소원", value: publicWishCount, unit: "개" },
            { label: "활성 카테고리", value: activeCategoryCount, unit: "개" },
            { label: "판매 중 테마", value: themeCount, unit: "개" },
            { label: "판매 중 오브젝트", value: objectCount, unit: "개" },
          ].map((s) => (
            <div key={s.label} className="rounded-xl border border-slate-200 bg-white p-3 text-center">
              <p className="text-xl font-bold text-slate-900">
                {s.value.toLocaleString()}
                <span className="ml-1 text-xs font-normal text-slate-500">{s.unit}</span>
              </p>
              <p className="mt-1 text-xs text-slate-500">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* 관리자 설정 폼 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          소원 개수/힘주기/에너지/감쇠/애니메이션 설정
        </h2>
        <WishRoomConfigForm canWrite={canWrite} rows={configViewRows} />
      </section>
    </div>
  );
}
