import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import PassPolicyCreateForm from "@/components/PassPolicyCreateForm";
import PassPolicyRow from "@/components/PassPolicyRow";

// [신규] 알림패스(AlarmPass) 관리자 화면 — Fortune Fusion 3대 재화 중 ①시간제
// 콘텐츠 열람권. Server Action(app/actions/pass-policies.ts)은 이미 완전
// 구현되어 있었으나(createPassPolicy/updatePassPolicy/deletePassPolicy,
// RBAC + operationLog 기록까지 완료), 대응하는 프론트 화면(이 파일)이 존재하지
// 않아 관리자가 알림패스 정책을 등록/수정할 방법이 없었다(문서1·문서6·문서7·
// 문서8에서 공통으로 지목된 "API는 있으나 UI만 부재" 케이스).
// 화면 구성:
//  1) 정책 관리(pass_policies) — 완전 CRUD (기존 Server Action 그대로 재사용)
//  2) 발급 이력 조회(user_passes, 조회 전용) — 회원별 발급/소진 이력 모니터링
export const dynamic = "force-dynamic";

const HISTORY_PAGE_SIZE = 20;

interface PassPoliciesPageProps {
  searchParams: Promise<{ historyPage?: string }>;
}

export default async function RewardPassPoliciesPage({ searchParams }: PassPoliciesPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const historyPage = Math.max(1, Number(params.historyPage ?? "1") || 1);

  const canWrite = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.write;
  const canDelete = !!RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward]?.delete;

  // ── 1) 정책 목록 ──
  const policies = await prisma.passPolicy.findMany({
    where: { deletedAt: null },
    orderBy: [{ passType: "asc" }, { id: "asc" }],
  });

  // ── 2) 발급 이력 조회 (단순 where만 사용, 복합쿼리 회피) ──
  const [historyTotal, histories] = await Promise.all([
    prisma.userPass.count(),
    prisma.userPass.findMany({
      orderBy: { createdAt: "desc" },
      skip: (historyPage - 1) * HISTORY_PAGE_SIZE,
      take: HISTORY_PAGE_SIZE,
      include: {
        user: { select: { nickname: true } },
        policy: { select: { name: true, passType: true } },
      },
    }),
  ]);
  const historyTotalPages = Math.max(1, Math.ceil(historyTotal / HISTORY_PAGE_SIZE));

  // ── 3) 요약 통계: 현재 활성중인 패스 수(expiresAt > now) ──
  const activeCount = await prisma.userPass.count({
    where: { expiresAt: { gt: new Date() } },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 알림패스</h1>
        <p className="mt-1 text-sm text-slate-400">
          시간제 콘텐츠 열람권(알림패스) 정책을 관리하고 회원별 발급/소진 이력을 조회합니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">등록된 정책 수</p>
          <p className="mt-2 text-2xl font-bold text-white">{policies.length}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">현재 활성중인 알림패스</p>
          <p className="mt-2 text-2xl font-bold text-emerald-400">{activeCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="text-sm text-slate-400">누적 발급 건수</p>
          <p className="mt-2 text-2xl font-bold text-white">{historyTotal.toLocaleString()}</p>
        </div>
      </div>

      {/* 1) 정책 관리 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-white">알림패스 정책 관리</h2>
        <PassPolicyCreateForm canWrite={canWrite} />
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">정책명</th>
                <th className="px-4 py-3">유형</th>
                <th className="px-4 py-3">지속시간</th>
                <th className="px-4 py-3">1일 한도</th>
                <th className="px-4 py-3">보너스P</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {policies.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 알림패스 정책이 없습니다.
                  </td>
                </tr>
              )}
              {policies.map((p) => (
                <PassPolicyRow key={p.id} policy={p} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 2) 발급 이력 조회 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">발급 이력 조회</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">발급일시</th>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">정책</th>
                <th className="px-4 py-3">발급경로</th>
                <th className="px-4 py-3">만료일시</th>
                <th className="px-4 py-3">상태</th>
              </tr>
            </thead>
            <tbody>
              {histories.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    발급 이력이 없습니다.
                  </td>
                </tr>
              )}
              {histories.map((h) => {
                const isActive = h.expiresAt.getTime() > Date.now();
                return (
                  <tr key={h.id} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                    <td className="px-4 py-3 text-slate-400">
                      {h.activatedAt.toISOString().slice(0, 19).replace("T", " ")}
                    </td>
                    <td className="px-4 py-3 text-slate-200">{h.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-300">{h.policy.name}</td>
                    <td className="px-4 py-3 font-mono text-slate-400">{h.sourceType}</td>
                    <td className="px-4 py-3 text-slate-400">
                      {h.expiresAt.toISOString().slice(0, 19).replace("T", " ")}
                    </td>
                    <td className="px-4 py-3">
                      {isActive ? (
                        <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
                          활성중
                        </span>
                      ) : (
                        <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
                          만료
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex items-center justify-center gap-1">
          {Array.from({ length: historyTotalPages }, (_, i) => i + 1)
            .slice(0, 20)
            .map((p) => (
              <a
                key={p}
                href={`/reward/pass-policies?${new URLSearchParams({
                  historyPage: String(p),
                }).toString()}`}
                className={`rounded-lg px-3 py-1.5 text-sm ${
                  p === historyPage ? "bg-indigo-600 text-white" : "text-slate-400 hover:bg-slate-800"
                }`}
              >
                {p}
              </a>
            ))}
        </div>
      </section>
    </div>
  );
}
