import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import RewardSubNav from "@/components/RewardSubNav";

// [재화 구조 정리 - 관리자 축소] 최종 5-메뉴 중 "5) 운영로그/내역확인" — 신규 조회
// 전용 화면. 기존 /reward/policies에 있던 "포인트 이력 조회" 섹션을 이 화면으로
// 이전하고(policies는 정책/설정 CRUD에만 집중), 복주머니 적립/사용 내역(PointHistory)
// + 최근 발급된 프리패스(UserPass)까지 한 곳에서 확인할 수 있게 한다.
// 관리자는 이 화면에서 값을 수정하지 않는다(조회 전용 - "관리자는 값만 조정,
// 구조는 변경 불가" 원칙과 별개로, 로그/내역 화면 자체는 항상 read-only).
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;
const PASS_PAGE_SIZE = 15;

interface OperationLogsPageProps {
  searchParams: Promise<{
    historyPage?: string;
    historyUserId?: string;
    historyType?: string;
    historySourceType?: string;
  }>;
}

export default async function RewardOperationLogsPage({
  searchParams,
}: OperationLogsPageProps) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const historyPage = Math.max(1, Number(params.historyPage ?? "1") || 1);
  const historyUserId = params.historyUserId ?? "";
  const historyType = params.historyType ?? "";
  const historySourceType = params.historySourceType ?? "";

  const historyWhere = {
    ...(historyUserId ? { userId: Number(historyUserId) } : {}),
    ...(historyType ? { type: historyType } : {}),
    ...(historySourceType ? { sourceType: historySourceType } : {}),
  };

  const [historyTotal, histories, userOptions, recentPasses] = await Promise.all([
    prisma.pointHistory.count({ where: historyWhere }),
    prisma.pointHistory.findMany({
      where: historyWhere,
      orderBy: { createdAt: "desc" },
      skip: (historyPage - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
      include: { user: { select: { nickname: true } } },
    }),
    prisma.user.findMany({
      where: { deletedAt: null },
      take: 200,
      orderBy: { id: "asc" },
      select: { id: true, nickname: true },
    }),
    prisma.userPass.findMany({
      orderBy: { createdAt: "desc" },
      take: PASS_PAGE_SIZE,
      include: {
        user: { select: { nickname: true } },
        policy: { select: { name: true } },
      },
    }),
  ]);
  const historyTotalPages = Math.max(1, Math.ceil(historyTotal / PAGE_SIZE));

  const filterQuery = {
    ...(historyUserId ? { historyUserId } : {}),
    ...(historyType ? { historyType } : {}),
    ...(historySourceType ? { historySourceType } : {}),
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">운영로그 / 내역확인</h1>
        <p className="mt-1 text-sm text-slate-500">
          복주머니 적립/사용 내역과 최근 발급된 프리패스를 조회합니다(조회 전용).
          관리자 계정의 CRUD 감사로그는{" "}
          <Link href="/audit-logs" className="text-indigo-700 hover:underline">
            운영/보안 &gt; 감사로그
          </Link>
          에서 확인할 수 있습니다.
        </p>
      </div>

      <RewardSubNav />

      {/* 복주머니 이력 조회 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">복주머니 적립/사용 내역</h2>
        <form
          method="GET"
          className="mb-4 flex flex-wrap gap-3 rounded-xl border border-slate-200 bg-white p-4"
        >
          <select
            name="historyUserId"
            defaultValue={historyUserId}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
          >
            <option value="">전체 회원</option>
            {userOptions.map((u) => (
              <option key={u.id} value={u.id}>
                {u.nickname}
              </option>
            ))}
          </select>
          <select
            name="historyType"
            defaultValue={historyType}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
          >
            <option value="">전체 유형</option>
            <option value="earn">적립(earn)</option>
            <option value="spend">차감(spend)</option>
          </select>
          <input
            name="historySourceType"
            defaultValue={historySourceType}
            placeholder="source_type 검색 (예: attendance, wish_bokju_send)"
            className="w-72 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none placeholder:text-slate-500 focus:border-indigo-500"
          />
          <button
            type="submit"
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
          >
            필터 적용
          </button>
        </form>

        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">일시</th>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">구분</th>
                <th className="px-4 py-3">source_type</th>
                <th className="px-4 py-3">개수</th>
                <th className="px-4 py-3">처리후 보유개수</th>
                <th className="px-4 py-3">메모</th>
              </tr>
            </thead>
            <tbody>
              {histories.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    조건에 맞는 이력이 없습니다.
                  </td>
                </tr>
              )}
              {histories.map((h) => (
                <tr key={h.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-500">
                    {h.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                  <td className="px-4 py-3 text-slate-700">{h.user.nickname}</td>
                  <td className="px-4 py-3">
                    {h.type === "earn" ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                        적립
                      </span>
                    ) : (
                      <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                        차감
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono text-slate-500">{h.sourceType}</td>
                  <td
                    className={`px-4 py-3 font-medium ${
                      h.amount > 0 ? "text-emerald-700" : "text-red-700"
                    }`}
                  >
                    {h.amount > 0 ? "+" : ""}
                    {h.amount.toLocaleString()}개
                  </td>
                  <td className="px-4 py-3 text-slate-600">{h.balanceAfter.toLocaleString()}개</td>
                  <td className="px-4 py-3 text-slate-500">{h.memo ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex items-center justify-center gap-1">
          {Array.from({ length: historyTotalPages }, (_, i) => i + 1)
            .slice(0, 20)
            .map((p) => (
              <a
                key={p}
                href={`/reward/operation-logs?${new URLSearchParams({
                  ...filterQuery,
                  historyPage: String(p),
                }).toString()}`}
                className={`rounded-lg px-3 py-1.5 text-sm ${
                  p === historyPage ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-100"
                }`}
              >
                {p}
              </a>
            ))}
        </div>
      </section>

      {/* 최근 발급된 프리패스 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">최근 발급된 프리패스</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">발급 시각</th>
                <th className="px-4 py-3">회원</th>
                <th className="px-4 py-3">패스 정책</th>
                <th className="px-4 py-3">발급 경로(source_type)</th>
                <th className="px-4 py-3">만료 시각</th>
                <th className="px-4 py-3">상태</th>
              </tr>
            </thead>
            <tbody>
              {recentPasses.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-slate-500">
                    발급된 프리패스가 없습니다.
                  </td>
                </tr>
              )}
              {recentPasses.map((p) => (
                <tr key={p.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 text-slate-500">
                    {p.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                  <td className="px-4 py-3 text-slate-700">{p.user.nickname}</td>
                  <td className="px-4 py-3 text-slate-700">{p.policy.name}</td>
                  <td className="px-4 py-3 font-mono text-slate-500">{p.sourceType}</td>
                  <td className="px-4 py-3 text-slate-500">
                    {p.expiresAt.toISOString().slice(0, 19).replace("T", " ")}
                  </td>
                  <td className="px-4 py-3">
                    {p.status === "active" ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                        active
                      </span>
                    ) : (
                      <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
                        {p.status}
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
