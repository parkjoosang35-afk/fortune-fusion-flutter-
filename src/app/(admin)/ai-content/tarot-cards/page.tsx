import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import TarotCardCreateForm from "@/components/TarotCardCreateForm";
import TarotCardRow from "@/components/TarotCardRow";

// 05_Admin_System_Design.md §3.2 "타로카드/스프레드 마스터 관리"
// 04A E-5 tarot_cards CRUD. 스프레드(E-6)는 이번 화면에서는 읽기 전용 요약만 노출.
export const dynamic = "force-dynamic";

export default async function TarotCardsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ai_content")) {
    redirect("/dashboard");
  }

  const [cards, spreads] = await Promise.all([
    prisma.tarotCard.findMany({
      where: { deletedAt: null },
      orderBy: { sortOrder: "asc" },
    }),
    prisma.tarotSpread.findMany({ where: { deletedAt: null }, orderBy: { cardCount: "asc" } }),
  ]);

  const canWrite =
    canAccessMenu(session.roleCode, "ai_content") &&
    !!RBAC_MATRIX.ai_content[session.roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;
  const canDelete = session.roleCode === "super_admin";

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">타로카드 마스터 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          타로 리딩에 사용되는 카드 마스터 데이터를 관리합니다. 총 {cards.length}장
        </p>
      </div>

      <TarotCardCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">순서</th>
              <th className="px-4 py-3">카드명</th>
              <th className="px-4 py-3">유형</th>
              <th className="px-4 py-3">의미</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {cards.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                  등록된 카드가 없습니다.
                </td>
              </tr>
            )}
            {cards.map((card) => (
              <TarotCardRow
                key={card.id}
                card={card}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>

      {/* 스프레드 요약(읽기 전용) — 05§3.2 범위상 카드 마스터가 핵심이며 스프레드는 참조용 표시 */}
      <section className="mt-6 rounded-xl border border-dashed border-slate-300 bg-white/40 p-5">
        <h2 className="mb-3 text-sm font-semibold text-slate-600">
          등록된 타로 스프레드 (참조용)
        </h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:grid-cols-4">
          {spreads.map((s) => (
            <div key={s.id} className="rounded-lg border border-slate-200 bg-white/40 p-3">
              <p className="text-sm font-medium text-slate-900">{s.name}</p>
              <p className="mt-1 text-xs text-slate-500">
                {s.cardCount}장 카드 {s.isPremium ? "· 프리미엄" : ""}
              </p>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
