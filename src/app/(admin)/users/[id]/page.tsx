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
  active: "bg-emerald-100 text-emerald-700",
  suspended: "bg-amber-100 text-amber-700",
  withdrawn: "bg-white text-slate-500",
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
      // [STEP12 - 관리자 회원별 프리패스+카테고리 이용현황] 최근 발급된
      // 프리패스(UserPass) 10건과, 각 패스별 카테고리 이용횟수
      // (PassCategoryUsage)를 함께 조회한다. categoryUsages는 패스 1건당
      // 카테고리별 usageCount를 추적하는 구조이므로, 패스 목록에 그대로
      // 중첩(include)해서 "이 패스로 오늘의운세 2/2회, 관상 1/2회" 형태로
      // 보여줄 수 있게 한다.
      passes: {
        orderBy: { createdAt: "desc" },
        take: 10,
        include: { policy: true, categoryUsages: true },
      },
    },
  });

  if (!user) {
    notFound();
  }

  // 카테고리 키 -> 표시용 한글 라벨 매핑(카테고리 마스터 조회로 최신화).
  const categoryLabelRows = await prisma.fortuneCategory.findMany({
    select: { categoryKey: true, title: true },
  });
  const categoryLabelMap = new Map(
    categoryLabelRows.map((c) => [c.categoryKey, c.title])
  );
  const labelForCategory = (key: string) => categoryLabelMap.get(key) ?? key;

  const now = new Date();
  const passStatusLabel = (status: string, expiresAt: Date) => {
    if (status === "revoked") return { text: "회수됨", cls: "text-red-700" };
    if (status === "expired" || expiresAt < now)
      return { text: "만료", cls: "text-slate-400" };
    return { text: "이용중", cls: "text-emerald-700" };
  };

  const canWrite =
    canAccessMenu(session.roleCode, "users") &&
    RBAC_MATRIX.users[session.roleCode as keyof typeof RBAC_MATRIX.users]
      ?.write;

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link
          href="/users"
          className="text-sm text-slate-500 hover:text-slate-900"
        >
          ← 회원 목록
        </Link>
      </div>

      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-slate-900">{user.nickname}</h1>
          <span
            className={`rounded-full px-2 py-1 text-xs font-medium ${STATUS_BADGE_CLASS[user.status] ?? "bg-white text-slate-500"}`}
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
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">
              프로필 정보
            </h2>
            <dl className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <dt className="text-slate-500">이메일</dt>
                <dd className="text-slate-700">{user.email ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">전화번호</dt>
                <dd className="text-slate-700">{user.phone ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">성별</dt>
                <dd className="text-slate-700">{user.gender ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">등급</dt>
                <dd className="text-slate-700">{user.grade?.name ?? "-"}</dd>
              </div>
              <div>
                <dt className="text-slate-500">가입경로</dt>
                <dd className="text-slate-700">{user.signupChannel}</dd>
              </div>
              <div>
                <dt className="text-slate-500">마케팅 수신동의</dt>
                <dd className="text-slate-700">
                  {user.marketingAgreed ? "동의" : "미동의"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">가입일</dt>
                <dd className="text-slate-700">
                  {user.createdAt.toISOString().slice(0, 19).replace("T", " ")}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">최근 로그인</dt>
                <dd className="text-slate-700">
                  {user.lastLoginAt
                    ? user.lastLoginAt.toISOString().slice(0, 19).replace("T", " ")
                    : "-"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">MBTI</dt>
                <dd className="text-slate-700">
                  {user.profile?.mbti ?? "-"}
                </dd>
              </div>
              <div>
                <dt className="text-slate-500">생년월일</dt>
                <dd className="text-slate-700">
                  {user.profile?.birthDate ?? "-"}
                  {user.profile?.isLunar ? " (음력)" : ""}
                </dd>
              </div>
              <div className="col-span-2">
                <dt className="text-slate-500">자기소개</dt>
                <dd className="text-slate-700">
                  {user.profile?.introText ?? "-"}
                </dd>
              </div>
              {user.status === "withdrawn" && (
                <div className="col-span-2">
                  <dt className="text-slate-500">탈퇴 사유</dt>
                  <dd className="text-amber-700">
                    {user.withdrawalReason ?? "-"}
                  </dd>
                </div>
              )}
            </dl>
          </section>

          {/* [STEP12 - 프리패스 & 카테고리 이용현황] user_passes + pass_category_usages */}
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">
              프리패스 &amp; 카테고리 이용현황 (최근 10건)
            </h2>
            {user.passes.length === 0 && (
              <p className="py-4 text-center text-sm text-slate-500">
                발급된 프리패스가 없습니다.
              </p>
            )}
            <div className="space-y-3">
              {user.passes.map((pass) => {
                const st = passStatusLabel(pass.status, pass.expiresAt);
                const maxUsage = pass.policy.categoryMaxUsage;
                return (
                  <div
                    key={pass.id}
                    className="rounded-lg border border-slate-200/80 p-3"
                  >
                    <div className="mb-2 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-slate-800">
                          {pass.policy.name}
                        </span>
                        <span className="rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-500">
                          {pass.sourceType}
                        </span>
                      </div>
                      <span className={`text-xs font-medium ${st.cls}`}>
                        {st.text}
                      </span>
                    </div>
                    <div className="mb-2 text-xs text-slate-500">
                      발급 {pass.activatedAt
                        .toISOString()
                        .slice(0, 16)
                        .replace("T", " ")}{" "}
                      → 만료{" "}
                      {pass.expiresAt.toISOString().slice(0, 16).replace("T", " ")}
                    </div>
                    {pass.categoryUsages.length === 0 ? (
                      <p className="text-xs text-slate-400">
                        아직 이용한 카테고리가 없습니다.
                      </p>
                    ) : (
                      <div className="flex flex-wrap gap-2">
                        {pass.categoryUsages.map((usage) => {
                          const reached =
                            maxUsage != null && usage.usageCount >= maxUsage;
                          return (
                            <span
                              key={usage.id}
                              className={`rounded-full px-2 py-1 text-xs ${
                                reached
                                  ? "bg-amber-100 text-amber-700"
                                  : "bg-slate-100 text-slate-600"
                              }`}
                            >
                              {labelForCategory(usage.categoryKey)}{" "}
                              {usage.usageCount}
                              {maxUsage != null ? `/${maxUsage}` : ""}회
                            </span>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>

          {/* 로그인 이력 — 04A A-4 user_login_logs */}
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">
              로그인 이력 (최근 10건)
            </h2>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
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
                    <tr key={log.id} className="border-b border-slate-200/60">
                      <td className="py-2 pr-4 text-slate-500">
                        {log.createdAt
                          .toISOString()
                          .slice(0, 19)
                          .replace("T", " ")}
                      </td>
                      <td className="py-2 pr-4 text-slate-600">
                        {log.loginType}
                      </td>
                      <td className="py-2 pr-4 text-slate-500">
                        {log.ipAddress}
                      </td>
                      <td className="py-2 pr-4">
                        <span
                          className={
                            log.successFlag
                              ? "text-emerald-700"
                              : "text-red-700"
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
            <section className="rounded-xl border border-slate-200 bg-white p-5">
              <h2 className="mb-4 text-sm font-semibold text-slate-900">
                탈퇴 이력
              </h2>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
                    <tr>
                      <th className="py-2 pr-4">요청일</th>
                      <th className="py-2 pr-4">사유</th>
                      <th className="py-2 pr-4">데이터 파기 예정일</th>
                      <th className="py-2 pr-4">파기 완료일</th>
                    </tr>
                  </thead>
                  <tbody>
                    {user.withdrawalLogs.map((log) => (
                      <tr key={log.id} className="border-b border-slate-200/60">
                        <td className="py-2 pr-4 text-slate-500">
                          {log.requestedAt.toISOString().slice(0, 10)}
                        </td>
                        <td className="py-2 pr-4 text-slate-600">
                          {log.reason ?? "-"}
                        </td>
                        <td className="py-2 pr-4 text-slate-500">
                          {log.dataPurgeScheduledAt.toISOString().slice(0, 10)}
                        </td>
                        <td className="py-2 pr-4 text-slate-500">
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
          <section className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-slate-900">
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
