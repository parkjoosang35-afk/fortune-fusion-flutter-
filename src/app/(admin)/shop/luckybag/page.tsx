import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import LuckybagGradeCreateForm from "@/components/LuckybagGradeCreateForm";
import LuckybagGradeRow from "@/components/LuckybagGradeRow";
import LuckybagSeasonCreateForm from "@/components/LuckybagSeasonCreateForm";
import LuckybagSeasonRow from "@/components/LuckybagSeasonRow";
import LuckybagProductCreateForm from "@/components/LuckybagProductCreateForm";
import LuckybagProductRow from "@/components/LuckybagProductRow";
import LuckybagRewardPoolCreateForm from "@/components/LuckybagRewardPoolCreateForm";
import LuckybagRewardPoolRow from "@/components/LuckybagRewardPoolRow";

// 05_Admin_System_Design.md §3.4 "상점 관리" — 3차 소단위: 복주머니 관리
// 04A I-1 luckybag_products, I-2 luckybag_grades(마스터), I-3 luckybag_reward_pools(확률테이블),
// I-4 luckybag_seasons CRUD + I-5 luckybag_open_logs(조회 전용, 어뷰징 모니터링).
// [스코프 결정] amulet(1차/2차)과 달리 luckybag은 마스터/상품/확률테이블/시즌/개봉이력이
// 서로 강하게 얽혀있어(보상풀↔상품↔등급, 개봉이력↔보상풀) 하나의 라우트에 모두 통합한다.
export const dynamic = "force-dynamic";

const REWARD_TYPE_LABEL: Record<string, string> = {
  none: "꽝",
  point: "포인트",
  amulet: "부적",
  giftcard_fragment: "상품권 조각",
};

const OPEN_LOG_STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  processing: { label: "처리중", cls: "bg-slate-800 text-slate-400" },
  completed: { label: "완료", cls: "bg-emerald-950/60 text-emerald-400" },
  failed: { label: "실패", cls: "bg-rose-950/60 text-rose-400" },
};

function fmtDate(d: Date | null): string {
  return d ? d.toISOString().slice(0, 19).replace("T", " ") : "-";
}

export default async function ShopLuckybagPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "shop")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.write;
  const canDelete = !!RBAC_MATRIX.shop[session.roleCode as keyof typeof RBAC_MATRIX.shop]?.delete;

  const [grades, seasons, products, rewardPools] = await Promise.all([
    prisma.luckybagGrade.findMany({ where: { deletedAt: null }, orderBy: { sortOrder: "asc" } }),
    prisma.luckybagSeason.findMany({ where: { deletedAt: null }, orderBy: { startAt: "desc" } }),
    prisma.luckybagProduct.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } }),
    prisma.luckybagRewardPool.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } }),
  ]);

  const productCountBySeason = new Map<number, number>();
  for (const p of products) {
    if (p.seasonId) {
      productCountBySeason.set(p.seasonId, (productCountBySeason.get(p.seasonId) ?? 0) + 1);
    }
  }

  const probabilitySumByProduct = new Map<number, number>();
  for (const pool of rewardPools) {
    probabilitySumByProduct.set(
      pool.luckybagProductId,
      (probabilitySumByProduct.get(pool.luckybagProductId) ?? 0) + pool.probability
    );
  }
  // ProbabilityEditor(클라이언트 컴포넌트)로 넘기기 위해 Map → plain object 변환
  const probabilitySumRecord: Record<number, number> = Object.fromEntries(probabilitySumByProduct);

  const seasonOptions = seasons.map((s) => ({ id: s.id, name: s.name }));
  const productOptions = products.map((p) => ({ id: p.id, name: p.name }));
  const gradeOptions = grades.map((g) => ({ id: g.id, name: g.name, code: g.code }));

  // ── I-5: 복주머니 개봉 이력 (조회 전용, 최근 30건) ──
  const openLogs = await prisma.luckybagOpenLog.findMany({
    orderBy: { createdAt: "desc" },
    take: 30,
    include: {
      user: { select: { nickname: true } },
      luckybagProduct: { select: { name: true } },
      rewardPool: { select: { rewardType: true, rewardAmount: true } },
    },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">상점 관리 — 복주머니</h1>
        <p className="mt-1 text-sm text-slate-400">
          복주머니 등급 마스터, 시즌/이벤트, 상품 및 확률테이블(보상풀)을 관리하고, 개봉 이력을
          조회합니다.
        </p>
      </div>

      {/* 1) 등급 마스터 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">복주머니 등급 마스터</h2>
        <LuckybagGradeCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">코드</th>
                <th className="px-4 py-3">등급명</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {grades.length === 0 && (
                <tr>
                  <td colSpan={3} className="px-4 py-10 text-center text-slate-500">
                    등록된 등급이 없습니다.
                  </td>
                </tr>
              )}
              {grades.map((g) => (
                <LuckybagGradeRow key={g.id} grade={g} canWrite={canWrite} />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2) 시즌/이벤트 관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">복주머니 시즌/이벤트 관리</h2>
        <LuckybagSeasonCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">시즌명</th>
                <th className="px-4 py-3">기간</th>
                <th className="px-4 py-3">연결 상품 수</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {seasons.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    등록된 시즌이 없습니다.
                  </td>
                </tr>
              )}
              {seasons.map((s) => (
                <LuckybagSeasonRow
                  key={s.id}
                  season={s}
                  productCount={productCountBySeason.get(s.id) ?? 0}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          [스코프 결정] event_id(04A I-4 원본, FK→events.id)는 events 도메인이 아직 구현되지
          않아 이번 단계에서는 시즌-이벤트 연결을 생략합니다.
        </p>
      </section>

      {/* 3) 복주머니 상품 관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">복주머니 상품 관리</h2>
        <LuckybagProductCreateForm canWrite={canWrite} seasons={seasonOptions} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">이미지</th>
                <th className="px-4 py-3">상품명</th>
                <th className="px-4 py-3">가격</th>
                <th className="px-4 py-3">시즌</th>
                <th className="px-4 py-3">확률테이블 상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {products.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 복주머니 상품이 없습니다.
                  </td>
                </tr>
              )}
              {products.map((p) => (
                <LuckybagProductRow
                  key={p.id}
                  product={p}
                  seasons={seasonOptions}
                  probabilitySum={probabilitySumByProduct.get(p.id) ?? 0}
                  canWrite={canWrite}
                  canDelete={canDelete}
                />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 4) 보상풀(확률테이블) 관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">
          복주머니 보상풀 관리 (확률테이블)
        </h2>
        <LuckybagRewardPoolCreateForm
          canWrite={canWrite}
          products={productOptions}
          grades={gradeOptions}
          probabilitySumByProduct={probabilitySumRecord}
        />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">상품</th>
                <th className="px-4 py-3">등급</th>
                <th className="px-4 py-3">보상유형</th>
                <th className="px-4 py-3">보상량</th>
                <th className="px-4 py-3">확률</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {rewardPools.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 보상 항목이 없습니다.
                  </td>
                </tr>
              )}
              {rewardPools.map((pool) => (
                <LuckybagRewardPoolRow
                  key={pool.id}
                  pool={pool}
                  products={productOptions}
                  grades={gradeOptions}
                  canWrite={canWrite}
                  canDelete={canDelete}
                  probabilitySumByProduct={probabilitySumRecord}
                />
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          04A I-3 명시: 그룹(luckybag_product_id 동일)별 확률 합계는 반드시 100%가 되어야 합니다.
          합계 100% 초과 시 서버에서 즉시 차단됩니다(위 상품 목록의 확률 합계 뱃지로 진행 상태 확인).
        </p>
      </section>

      {/* 5) 복주머니 개봉 이력 (조회 전용, 어뷰징 모니터링) */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">
          복주머니 개봉 이력 (조회 전용, 최근 30건 — 어뷰징 모니터링)
        </h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">복주머니</th>
                <th className="px-4 py-3">추첨 결과</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">개봉 시각</th>
              </tr>
            </thead>
            <tbody>
              {openLogs.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-10 text-center text-slate-500">
                    개봉 이력이 없습니다.
                  </td>
                </tr>
              )}
              {openLogs.map((log) => {
                const st = OPEN_LOG_STATUS_LABEL[log.status] ?? {
                  label: log.status,
                  cls: "bg-slate-800 text-slate-400",
                };
                return (
                  <tr key={log.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 text-slate-200">{log.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-300">{log.luckybagProduct.name}</td>
                    <td className="px-4 py-3 text-slate-400">
                      {REWARD_TYPE_LABEL[log.rewardPool.rewardType] ?? log.rewardPool.rewardType}
                      {log.rewardPool.rewardAmount ? ` x${log.rewardPool.rewardAmount}` : ""}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(log.createdAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 섹션은 조회 전용입니다. 회원의 복주머니 구매/개봉 처리는 앱(회원측) 활동에서
          발생하며, 관리자 화면에서는 추첨 결과와 어뷰징 패턴만 모니터링합니다.
        </p>
      </section>
    </div>
  );
}
