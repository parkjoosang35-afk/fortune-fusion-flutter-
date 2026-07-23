import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import UserStatusChangeForm from "@/components/UserStatusChangeForm";

// 05_Admin_System_Design.md §3.1 "회원 상세"
// 프로필 정보, 로그인 이력(user_login_logs) 구현.
// [범위 제외] 지갑 잔액(C-1 wallets), AI이용 히스토리(도메인E), 보유 부적/상품권(도메인H/J)은
// 해당 도메인이 아직 구현되지 않아 절대원칙①(설계서기준개발)에 따라 이번 단계에서는
// 프로필 + 로그인이력 + 탈퇴이력만 노출하고, 나머지는 "추후 해당 도메인 구현 시 연동" 안내로 대체한다.
export const dynamic = "force-dynamic";

const STATUS_LABEL: Record<string, string> = {
  active: "정상",
  suspended: "정지",
  withdrawn: "탈퇴",
};

const STATUS_BADGE_CLASS: Record<string, string> = {
  active: "bg-emerald-950/60 text-emerald-400",
  suspended: "bg-amber-950/60 text-amber-400",
  withdrawn: "bg-slate-800 text-slate-400",
};

interface UserDetailPageProps {
  params: Promise<{ id: string }>;
}

export default async function UserDetailPage({ params }: UserDetailPageProps) {
  const session = await verifyAdminSession();
  const { id } = await params;
  const userId = Number(id);

  if (!Number.isInteger(userId) || userId <= 0) {
    notFound();
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      grade: true,
      profile: true,
      loginLogs: { orderBy: { createdAt: "desc" }, take: 10 },
      withdrawalLogs: { orderBy: { requestedAt: "desc" } },
    },
  });

  if (!user) {
    notFound();
  }

  const canWrite =
    canAccessMenu(session.roleCode, "users") &&
    RBAC_MATRIX.users[session.roleCode as keyof typeof RBAC_MATRIX.users]
      ?.write;

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link
          href="/users"
          className="text-sm text-slate-400 hover:text-white"
        >
          ← 회원 목록
        </Link>
      </div>

      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-white">{user.nickname}</h1>
          <span
            className={`rounded-full px-2 py-1 text-xs font-medium ${STATUS_BADGE_CLASS[user.status] ?? "bg-slate-800 text-slate-400"}`}
          >
            {STATUS_LABEL[user.status] ?? user.status}
          </span>
        </div>
        <span className="text-sm text-slate-500">회원 ID: {user.id}</span>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* 좌측: 프로필 정보 + 로그인이력 */}
        <div className="space-y-6 lg:col-span-2">
          {/* 프로필 정보 — 04A A-1/A-2 */}
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">
              프로필 정보
            </h2>
            <dl className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <dt className="text-slate-500">이메일</dt>
                <dd className="text-slate-200">{user.email ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">전화번호</dt>
                <dd className="text-slate-200">{user.phone ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">성별</dt>
                <dd className="text-slate-200">{user.gender ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">등급</dt>
                <dd className="text-slate-200">{user.grade?.name ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">가입경로</dt>
                <dd className="text-slate-200">{user.signupChannel}</dd>
              </div>
              <div>
                <dt className="text-slate-500">마케팅 수신동의</dt>
                <dd className="text-slate-200">
                  {user.marketingAgreed ? "동의" : "미동의"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">가입일</dt>
                <dd className="text-slate-200">
                  {user.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">최근 로그인</dt>
                <dd className="text-slate-200">
                  {user.lastLoginAt
                    ? user.lastLoginAt.toISOString().slice(0, 19).replace("T", " ")
                    : "-"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">MBTI</dt>
                <dd className="text-slate-200">
                  {user.profile?.mbti ?? "-"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">생년월일</dt>
                <dd className="text-slate-200">
                  {user.profile?.birthDate ?? "-"}
                  {user.profile?.isLunar ? " (음력)" : ""}
                </dd>
              </div>
              <div className="col-span-2">
                <dt className="text-slate-500">자기소개</dt>
                <dd className="text-slate-200">
                  {user.profile?.introText ?? "-"}
                </dd>
              </div>
              {user.status === "withdrawn" && (
                <div className="col-span-2">
                  <dt className="text-slate-500">탈퇴 사유</dt>
                  <dd className="text-amber-400">
                    {user.withdrawalReason ?? "-"}
                  </dd>
                </div>
              )}
            </dl>
          </section>

          {/* 참조용 안내 — 미구현 도메인 */}
          <section className="rounded-xl border border-dashed border-slate-700 bg-slate-900/40 p-5">
            <h2 className="mb-2 text-sm font-semibold text-slate-300">
              지갑 잔액 · AI 이용 히스토리 · 보유 부적/상품권
            </h2>
            <p className="text-sm text-slate-500">
              해당 정보는 지갑(C-1) · AI콘텐츠(도메인E) · 상점(도메인H/J)
              도메인이 아직 구현되지 않아, 각 Phase18-x 단계에서 구현 완료
              후 이 화면에 순차적으로 연동됩니다.
            </p>
          </section>

          {/* 로그인 이력 — 04A A-4 user_login_logs */}
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">
              로그인 이력 (최근 10건)
            </h2>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
                  <tr>
                    <th className="py-2 pr-4">일시</th>
                    <th className="py-2 pr-4">방식</th>
                    <th className="py-2 pr-4">IP</th>
                    <th className="py-2 pr-4">결과</th>
                  </tr>
                </thead>
                <tbody>
                  {user.loginLogs.length === 0 && (
                    <tr>
                      <td
                        colSpan={4}
                        className="py-6 text-center text-slate-500"
                      >
                        로그인 이력이 없습니다.
                      </td>
                    </tr>
                  )}
                  {user.loginLogs.map((log) => (
                    <tr key={log.id} className="border-b border-slate-800/60">
                      <td className="py-2 pr-4 text-slate-400">
                        {log.createdAt
                          .toISOString()
                          .slice(0, 19)
                          .replace("T", " ")}
                      </td>
                      <td className="py-2 pr-4 text-slate-300">
                        {log.loginType}
                      </td>
                      <td className="py-2 pr-4 text-slate-400">
                        {log.ipAddress}
                      </td>
                      <td className="py-2 pr-4">
                        <span
                          className={
                            log.successFlag
                              ? "text-emerald-400"
                              : "text-red-400"
                          }
                        >
                          {log.successFlag ? "성공" : "실패"}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          {/* 탈퇴 이력 — 04A A-11 user_withdrawal_logs */}
          {user.withdrawalLogs.length > 0 && (
            <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
              <h2 className="mb-4 text-sm font-semibold text-white">
                탈퇴 이력
              </h2>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
                    <tr>
                      <th className="py-2 pr-4">요청일</th>
                      <th className="py-2 pr-4">사유</th>
                      <th className="py-2 pr-4">데이터 파기 예정일</th>
                      <th className="py-2 pr-4">파기 완료일</th>
                    </tr>
                  </thead>
                  <tbody>
                    {user.withdrawalLogs.map((log) => (
                      <tr key={log.id} className="border-b border-slate-800/60">
                        <td className="py-2 pr-4 text-slate-400">
                          {log.requestedAt.toISOString().slice(0, 10)}
                        </td>
                        <td className="py-2 pr-4 text-slate-300">
                          {log.reason ?? "-"}
                        </td>
                        <td className="py-2 pr-4 text-slate-400">
                          {log.dataPurgeScheduledAt.toISOString().slice(0, 10)}
                        </td>
                        <td className="py-2 pr-4 text-slate-400">
                          {log.dataPurgedAt
                            ? log.dataPurgedAt.toISOString().slice(0, 10)
                            : "-"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}
        </div>

        {/* 우측: 상태 변경 */}
        <div>
          <section className="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <h2 className="mb-4 text-sm font-semibold text-white">
              상태 변경
            </h2>
            <UserStatusChangeForm
              userId={user.id}
              currentStatus={user.status}
              canWrite={!!canWrite}
            />
          </section>
        </div>
      </div>
    </div>
  );
}
