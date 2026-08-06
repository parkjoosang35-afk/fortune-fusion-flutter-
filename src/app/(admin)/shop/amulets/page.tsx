import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import AmuletGradeCreateForm from "@/components/AmuletGradeCreateForm";
import AmuletGradeRow from "@/components/AmuletGradeRow";
import AmuletItemCreateForm from "@/components/AmuletItemCreateForm";
import AmuletItemRow from "@/components/AmuletItemRow";

// 05_Admin_System_Design.md §3.4 "상점 관리"
// 1차 소단위: 디지털부적 상품 관리 — 04A H-1 amulet_items + H-2 amulet_grades(마스터) CRUD.
// 2차 소단위: 부적 지급/보유 이력 조회 — 04A H-3 user_amulets, H-4 amulet_usage_logs,
//   H-5 amulet_gifts, H-6 amulet_collections. 회원 활동 결과 데이터이므로 조회 전용으로만
//   노출한다(missions 화면의 user_missions 패턴과 동일).
export const dynamic = "force-dynamic";

const SOURCE_TYPE_LABEL: Record<string, string> = {
  purchase: "구매",
  event: "이벤트",
  gift: "선물수령",
  luckybag: "복주머니",
};

const AMULET_STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  held: { label: "보유중", cls: "bg-white text-slate-500" },
  used: { label: "사용완료", cls: "bg-emerald-100 text-emerald-700" },
  expired: { label: "만료", cls: "bg-rose-100 text-rose-700" },
  gifted: { label: "선물함", cls: "bg-amber-100 text-amber-700" },
};

function fmtDate(d: Date | null): string {
  return d ? d.toISOString().slice(0, 19).replace("T", " ") : "-";
}

export default async function ShopAmuletsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.write;
  const canDelete = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.delete;

  const [grades, items] = await Promise.all([
    prisma.amuletGrade.findMany({
      where: { deletedAt: null },
      orderBy: { sortOrder: "asc" },
    }),
    prisma.amuletItem.findMany({
      where: { deletedAt: null },
      orderBy: [{ gradeId: "asc" }, { id: "asc" }],
    }),
  ]);

  const itemCountByGrade = new Map<number, number>();
  for (const item of items) {
    itemCountByGrade.set(item.gradeId, (itemCountByGrade.get(item.gradeId) ?? 0) + 1);
  }

  const gradeOptions = grades.map((g) => ({ id: g.id, name: g.name, code: g.code }));

  // ── 2차 소단위: 부적 지급/보유 이력 조회 (조회 전용, 최근 50건) ──
  const userAmulets = await prisma.userAmulet.findMany({
    orderBy: { acquiredAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true } },
      amuletItem: { select: { name: true } },
    },
  });

  const usageLogs = await prisma.amuletUsageLog.findMany({
    orderBy: { createdAt: "desc" },
    take: 20,
    include: {
      userAmulet: {
        select: {
          user: { select: { nickname: true } },
          amuletItem: { select: { name: true } },
        },
      },
    },
  });

  const gifts = await prisma.amuletGift.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: "desc" },
    take: 20,
    include: {
      fromUser: { select: { nickname: true } },
      toUser: { select: { nickname: true } },
      userAmulet: { select: { amuletItem: { select: { name: true } } } },
    },
  });

  const collectionCount = await prisma.amuletCollection.count();

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">상점 관리 — 디지털부적</h1>
        <p className="mt-1 text-sm text-slate-500">
          부적 등급 마스터와 부적 상품(종류/등급/효과/이미지/AI생성여부/가격)을 관리합니다.
        </p>
      </div>

      {/* 1) 등급 마스터 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">부적 등급 마스터</h2>
        <AmuletGradeCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">코드</th>
                <th className="px-4 py-3">등급명</th>
                <th className="px-4 py-3">상품 수</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {grades.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 등급이 없습니다.
                  </td>
                </tr>
              )}
              {grades.map((g) => (
                <AmuletGradeRow
                  key={g.id}
                  grade={g}
                  itemCount={itemCountByGrade.get(g.id) ?? 0}
                  canWrite={canWrite}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2) 부적 상품 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">부적 상품 관리</h2>
        <AmuletItemCreateForm canWrite={canWrite} grades={gradeOptions} />
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">이미지</th>
                <th className="px-4 py-3">이름</th>
                <th className="px-4 py-3">등급</th>
                <th className="px-4 py-3">효과</th>
                <th className="px-4 py-3">가격</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 부적 상품이 없습니다.
                  </td>
                </tr>
              )}
              {items.map((item) => (
                <AmuletItemRow
                  key={item.id}
                  item={item}
                  grades={gradeOptions}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">총 {items.length}종 등록됨.</p>
      </section>

      {/* 3) 부적 지급/보유 이력 조회 (조회 전용) */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          부적 지급/보유 이력 (조회 전용, 최근 50건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">부적</th>
                <th className="px-4 py-3">획득경로</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">획득 시각</th>
                <th className="px-4 py-3">만료 시각</th>
              </tr>
            </thead>
            <tbody>
              {userAmulets.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    지급/보유 이력이 없습니다.
                  </td>
                </tr>
              )}
              {userAmulets.map((ua) => {
                const st = AMULET_STATUS_LABEL[ua.status] ?? {
                  label: ua.status,
                  cls: "bg-white text-slate-500",
                };
                return (
                  <tr key={ua.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                    <td className="px-4 py-3 text-slate-700">{ua.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-600">{ua.amuletItem.name}</td>
                    <td className="px-4 py-3 text-slate-500">
                      {SOURCE_TYPE_LABEL[ua.sourceType] ?? ua.sourceType}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(ua.acquiredAt)}</td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(ua.expiresAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 회원의 부적 지급/사용/선물/도감(수집) 처리는 앱(회원측)
          활동에서 발생하며, 관리자 화면에서는 결과만 모니터링합니다. 도감 진행 레코드
          (amulet_collections) 총 {collectionCount.toLocaleString()}건 누적.
        </p>
      </section>

      {/* 4) 부적 사용 이력 (조회 전용) */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          부적 사용 이력 (조회 전용, 최근 20건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">부적</th>
                <th className="px-4 py-3">사용 컨텍스트</th>
                <th className="px-4 py-3">사용 시각</th>
              </tr>
            </thead>
            <tbody>
              {usageLogs.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    사용 이력이 없습니다.
                  </td>
                </tr>
              )}
              {usageLogs.map((log) => (
                <tr key={log.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-700">{log.userAmulet.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-600">{log.userAmulet.amuletItem.name}</td>
                  <td className="px-4 py-3 text-slate-500">{log.usedContextType ?? "-"}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(log.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 5) 부적 선물 이력 (조회 전용) */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          부적 선물 이력 (조회 전용, 최근 20건)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">보낸 회원</th>
                <th className="px-4 py-3">받은 회원</th>
                <th className="px-4 py-3">부적</th>
                <th className="px-4 py-3">메시지</th>
                <th className="px-4 py-3">시각</th>
              </tr>
            </thead>
            <tbody>
              {gifts.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    선물 이력이 없습니다.
                  </td>
                </tr>
              )}
              {gifts.map((g) => (
                <tr key={g.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-700">{g.fromUser.nickname}</td>
                  <td className="px-4 py-3 text-slate-700">{g.toUser.nickname}</td>
                  <td className="px-4 py-3 text-slate-600">{g.userAmulet.amuletItem.name}</td>
                  <td className="px-4 py-3 text-slate-500">{g.message ?? "-"}</td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(g.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
