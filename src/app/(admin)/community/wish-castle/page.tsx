import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import WishConfigForm from "@/components/WishConfigForm";
import { WISH_CANDLE_LEVELS, WISH_CONFIG_KEYS } from "@/lib/wish-config-meta";
import WishReviewFeatureRow from "@/components/WishReviewFeatureRow";

// [소원성(Wish Castle) 확장] 커뮤니티 관리 6번째 탭 — 촛불 레벨 임계값/보상/문구/
// 애니메이션 ON-OFF를 CMS에서 즉시 반영. RBAC는 기존 community 매트릭스를 그대로
// 재사용한다(신규 권한 항목 추가 없음 — 기존 시스템 미침해 원칙).
export const dynamic = "force-dynamic";

export default async function WishCastlePage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "community")) {
    redirect("/dashboard");
  }

  const menuWrite = !!RBAC_MATRIX.community[session.roleCode as keyof typeof RBAC_MATRIX.community]?.write;
  const canWrite = menuWrite && session.roleCode !== "cs";

  const configRows = await prisma.wishConfig.findMany({
    where: { key: { in: WISH_CONFIG_KEYS.map((k) => k.key) } },
  });
  const configViewRows = configRows.map((r) => ({
    key: r.key,
    value: r.value,
    updatedAt: r.updatedAt.toISOString(),
    updatedBy: r.updatedBy,
  }));

  // 명예의 전당 수동 선정용: 최종 레벨(4)에 도달한 소원 + 최근 성취 후기 목록
  const [milestoneWishes, reviews] = await Promise.all([
    prisma.wish.findMany({
      where: { candleLevel: 4, deletedAt: null },
      include: { user: { select: { nickname: true } } },
      orderBy: { achievedAt: "desc" },
      take: 30,
    }),
    prisma.wishReview.findMany({
      where: { status: "visible" },
      include: { wish: { include: { user: { select: { nickname: true } } } } },
      orderBy: { createdAt: "desc" },
      take: 30,
    }),
  ]);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">커뮤니티 관리 — 🏰 소원성 설정</h1>
        <p className="mt-1 text-sm text-slate-500">
          촛불 성장 시스템의 레벨 임계값, 복주머니 보상, 응원 문구, 애니메이션
          ON/OFF를 관리합니다. 저장 즉시 앱 API에 반영됩니다.
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
          <Link href="/community/likes" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            좋아요 통계
          </Link>
          <Link href="/community/files" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            파일/업로드
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-slate-900">소원성 설정</span>
        </nav>
      </div>

      {/* 촛불 5레벨 안내 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">촛불 성장 5단계</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          {WISH_CANDLE_LEVELS.map((lv) => (
            <div
              key={lv.level}
              className="rounded-xl border border-slate-200 bg-white p-3 text-center"
            >
              <p className="text-2xl">{lv.emoji}</p>
              <p className="mt-1 text-xs text-slate-500">레벨 {lv.level}</p>
              <p className="text-sm font-medium text-slate-900">{lv.name}</p>
            </div>
          ))}
        </div>
      </section>

      {/* 관리자 설정 폼 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">레벨/보상/문구/애니메이션 설정</h2>
        <WishConfigForm canWrite={canWrite} rows={configViewRows} />
      </section>

      {/* 명예의 전당 수동 선정 — 최종 레벨 도달 소원 목록 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          🏆 명예의 전당 후보 (최종 레벨 도달 소원)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">내용</th>
                <th className="px-4 py-3">누적 복주머니</th>
                <th className="px-4 py-3">최종 도달 시각</th>
              </tr>
            </thead>
            <tbody>
              {milestoneWishes.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    아직 최종 레벨에 도달한 소원이 없습니다.
                  </td>
                </tr>
              )}
              {milestoneWishes.map((w) => (
                <tr key={w.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-700">
                    {w.isAnonymous ? "익명" : w.user.nickname}
                  </td>
                  <td className="max-w-md truncate px-4 py-3 text-slate-600">{w.content}</td>
                  <td className="px-4 py-3 text-amber-700">{w.bokjuCount.toLocaleString()}개</td>
                  <td className="px-4 py-3 text-slate-500">
                    {w.achievedAt ? w.achievedAt.toISOString().slice(0, 19).replace("T", " ") : "-"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 성취 후기 목록 + 명예의 전당 수동 선정(isFeatured) 토글 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">성취 후기 — 명예의 전당 선정</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">후기 내용</th>
                <th className="px-4 py-3">작성일</th>
                <th className="px-4 py-3">명예의 전당 선정</th>
              </tr>
            </thead>
            <tbody>
              {reviews.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    아직 등록된 성취 후기가 없습니다.
                  </td>
                </tr>
              )}
              {reviews.map((r) => (
                <WishReviewFeatureRow
                  key={r.id}
                  review={{
                    id: r.id,
                    authorNickname: r.wish.isAnonymous ? "익명" : r.wish.user.nickname,
                    content: r.content,
                    createdAt: r.createdAt.toISOString(),
                    isFeatured: r.isFeatured,
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
