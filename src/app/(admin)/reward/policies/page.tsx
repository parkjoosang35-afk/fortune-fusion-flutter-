import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import RewardSubNav from "@/components/RewardSubNav";
import PointPolicyCreateForm from "@/components/PointPolicyCreateForm";
import PointPolicyRow from "@/components/PointPolicyRow";
import PointAdjustForm from "@/components/PointAdjustForm";
import EconomyConfigForm from "@/components/EconomyConfigForm";
import { ECONOMY_CONFIG_KEYS } from "@/lib/economy-config-meta";

// 05_Admin_System_Design.md §3.3 "리워드 관리" — 1차 소단위(지갑/포인트, 04A 도메인C)
// 화면 3종을 /reward/policies 라우트 하위 섹션으로 통합 구현:
//  1) 포인트 정책 설정(point_policies) — earn/spend 통합, "무료/유료 정책 설정" 흡수
//  2) 포인트 조정(수동 지급/회수) — point_histories 신규 레코드 생성(직접 balance수정 금지)
//  3) 만료 배치 모니터링(point_expiry_batches, 조회 전용)
//
// [재화 구조 정리 - 관리자 축소] 이 화면은 "값 조정" 전용으로 유지하고, 기존에
// 여기 있던 "포인트 이력 조회" 섹션은 최종 5-메뉴 중 "운영로그/내역확인"
// (/reward/operation-logs)으로 이전했다(조회 전용 화면은 별도 메뉴로 분리).
export const dynamic = "force-dynamic";

function today(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

export default async function RewardPoliciesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const canWrite = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.write;
  const canDelete = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.delete;

  // ── 1) 정책 목록 ──
  const policies = await prisma.pointPolicy.findMany({
    where: { deletedAt: null },
    orderBy: { sourceType: "asc" },
  });

  // ── 2) 포인트 조정용 회원+지갑 목록 (최대 200명, 소단위 규모 고려) ──
  const usersWithWallet = await prisma.user.findMany({
    where: { deletedAt: null },
    take: 200,
    orderBy: { id: "asc" },
    select: {
      id: true,
      nickname: true,
      wallets: { where: { currencyType: "POINT" }, select: { balance: true } },
    },
  });
  const userOptions = usersWithWallet.map((u) => ({
    id: u.id,
    nickname: u.nickname,
    balance: u.wallets[0]?.balance ?? 0,
  }));

  // ── 3) 만료 배치 이력 ──
  const expiryBatches = await prisma.pointExpiryBatch.findMany({
    orderBy: { targetDate: "desc" },
    take: 12,
  });

  // ── 4) 복(福) 경제 설정 (Phase4, 옵션B — economy_config) ──
  const economyConfigRows = await prisma.economyConfig.findMany({
    where: { key: { in: ECONOMY_CONFIG_KEYS.map((k) => k.key) } },
  });
  const economyConfigViewRows = economyConfigRows.map((r) => ({
    key: r.key,
    value: r.value,
    updatedAt: r.updatedAt.toISOString(),
    updatedBy: r.updatedBy,
  }));

  // ── 5) 금일 "복 나누기(send_bok)" 발행/환급 요약 ──
  const sendBokToday = await prisma.pointHistory.findMany({
    where: { sourceType: "send_bok", createdAt: { gte: today() } },
    select: { amount: true, type: true },
  });
  const sendBokSentToday = sendBokToday
    .filter((h) => h.type === "spend")
    .reduce((s, h) => s + Math.abs(h.amount), 0);
  const sendBokRefundToday = sendBokToday
    .filter((h) => h.type === "earn" && h.amount > 0)
    .reduce((s, h) => s + h.amount, 0);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">복주머니관리 — 경제 정책(일일상한)</h1>
        <p className="mt-1 text-sm text-slate-400">
          지갑/포인트 정책, 수동 조정, 만료 배치 모니터링을 관리합니다. 적립/사용
          내역 조회는{" "}
          <Link href="/reward/operation-logs" className="text-indigo-400 hover:underline">
            운영로그/내역확인
          </Link>{" "}
          화면을 이용하세요.
        </p>
      </div>

      <RewardSubNav />

      {/* 4) 복(福) 경제 설정 — Phase4(관리자 대시보드, 옵션B) */}
      <section className="mb-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">복(福) 경제 설정</h2>
          <p className="text-xs text-slate-500">
            &quot;복은 나눌수록 커진다&quot; 경제 철학의 핀조절 레버(economy_config) — 저장 즉시 API에 반영
          </p>
        </div>
        <div className="mb-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🔁 금일 복 나누기 발행(보낸 개수)</p>
            <p className="mt-2 text-2xl font-bold text-white">{sendBokSentToday.toLocaleString()}개</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🔁 금일 복 나누기 환급(양쪽 증식분)</p>
            <p className="mt-2 text-2xl font-bold text-emerald-400">
              +{sendBokRefundToday.toLocaleString()}개
            </p>
          </div>
        </div>
        <EconomyConfigForm canWrite={canWrite} rows={economyConfigViewRows} />
      </section>

      {/* 1) 포인트 정책 설정 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">포인트 정책 설정</h2>
        <PointPolicyCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">source_type</th>
                <th className="px-4 py-3">유형</th>
                <th className="px-4 py-3">금액</th>
                <th className="px-4 py-3">1일 한도</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {policies.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    등록된 정책이 없습니다.
                  </td>
                </tr>
              )}
              {policies.map((p) => (
                <PointPolicyRow key={p.id} policy={p} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2) 포인트 조정 (수동 지급/회수) */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">포인트 조정 (수동 지급/회수)</h2>
        <PointAdjustForm canWrite={canWrite} users={userOptions} />
      </section>

      {/* 3) 만료 배치 모니터링 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">만료 배치 모니터링</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">처리 대상일</th>
                <th className="px-4 py-3">총 소멸 개수</th>
                <th className="px-4 py-3">처리 유저 수</th>
                <th className="px-4 py-3">배치 실행 시각</th>
              </tr>
            </thead>
            <tbody>
              {expiryBatches.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-slate-500">
                    아직 실행된 만료 배치가 없습니다.
                  </td>
                </tr>
              )}
              {expiryBatches.map((b) => (
                <tr key={b.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">
                    {b.targetDate.toISOString().slice(0, 10)}
                  </td>
                  <td className="px-4 py-3 text-amber-400">
                    {b.expiredAmountTotal.toLocaleString()}개
                  </td>
                  <td className="px-4 py-3 text-slate-300">{b.processedUserCount.toLocaleString()}명</td>
                  <td className="px-4 py-3 text-slate-500">
                    {b.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          이 화면은 조회 전용입니다. 배치 실행 자체는 서버 스케줄러(백엔드 배치 잡)에서
          수행되며, 관리자 화면에서는 실행 이력만 모니터링합니다.
        </p>
      </section>
    </div>
  );
}
