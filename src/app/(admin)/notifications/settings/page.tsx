import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.9 "알림 관리" — 4차(마지막) 소단위: "발송 설정 현황"
// "notification_preferences(회원별 수신동의) 집계, push_tokens 유효성 모니터링"
// 04A N-3/N-4 — 회원 앱에서 직접 설정하는 값이므로 관리자는 조회(집계/모니터링)만
// 한다(원칙② 준수: 04A에 관리자 CUD 스펙 없음). Server Actions 없음.
export const dynamic = "force-dynamic";

const CATEGORY_LABEL: Record<string, string> = {
  marketing: "마케팅",
  fortune_update: "운세 업데이트",
  matching: "매칭",
  community: "커뮤니티",
};

const PLATFORM_LABEL: Record<string, string> = {
  android: "Android",
  ios: "iOS",
  web: "Web",
};

export default async function NotificationSettingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "notifications")) {
    redirect("/dashboard");
  }

  const preferences = await prisma.notificationPreference.findMany({
    where: { deletedAt: null },
    select: { category: true, isEnabled: true },
  });

  // 카테고리별 동의/비동의 집계(메모리 집계 — 복합 groupBy 인덱스 의존 회피 전례 재사용)
  const categoryStats = Object.keys(CATEGORY_LABEL).map((category) => {
    const rows = preferences.filter((p) => p.category === category);
    const enabled = rows.filter((p) => p.isEnabled).length;
    const total = rows.length;
    return {
      category,
      enabled,
      disabled: total - enabled,
      total,
      rate: total > 0 ? Math.round((enabled / total) * 1000) / 10 : 0,
    };
  });

  const pushTokens = await prisma.pushToken.findMany({
    where: { deletedAt: null },
    select: { platform: true, userId: true },
  });
  const platformStats = Object.keys(PLATFORM_LABEL).map((platform) => ({
    platform,
    count: pushTokens.filter((t) => t.platform === platform).length,
  }));
  const distinctUsersWithToken = new Set(pushTokens.map((t) => t.userId)).size;

  const totalActiveUsers = await prisma.user.count({ where: { deletedAt: null, status: "active" } });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">알림 관리 — 발송 설정 현황</h1>
        <p className="mt-1 text-sm text-slate-400">
          회원별 알림 수신동의(카테고리별) 집계와 푸시 토큰(플랫폼별) 유효성 현황을 모니터링합니다.
          (조회 전용 — 회원이 앱에서 직접 설정하는 값입니다)
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/notifications/templates" className="px-3 py-2 text-slate-400 hover:text-white">
            알림 템플릿 관리
          </Link>
          <Link href="/notifications/history" className="px-3 py-2 text-slate-400 hover:text-white">
            발송 이력 조회
          </Link>
          <Link href="/notifications/segment-send" className="px-3 py-2 text-slate-400 hover:text-white">
            세그먼트 발송
          </Link>
          <Link
            href="/notifications/settings"
            className="px-3 py-2 font-medium text-white border-b-2 border-indigo-500"
          >
            발송 설정 현황
          </Link>
        </nav>
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-white">카테고리별 수신동의 현황</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">카테고리</th>
                <th className="px-4 py-3">동의</th>
                <th className="px-4 py-3">비동의</th>
                <th className="px-4 py-3">전체</th>
                <th className="px-4 py-3">동의율</th>
              </tr>
            </thead>
            <tbody>
              {categoryStats.map((s) => (
                <tr key={s.category} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{CATEGORY_LABEL[s.category]}</td>
                  <td className="px-4 py-3 text-emerald-400">{s.enabled}건</td>
                  <td className="px-4 py-3 text-slate-500">{s.disabled}건</td>
                  <td className="px-4 py-3 text-slate-400">{s.total}건</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="h-1.5 w-24 overflow-hidden rounded-full bg-slate-800">
                        <div
                          className="h-full bg-indigo-500"
                          style={{ width: `${s.rate}%` }}
                        />
                      </div>
                      <span className="text-xs text-slate-400">{s.rate}%</span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-2 text-xs text-slate-500">
          총 알림 수신설정 레코드 {preferences.length}건(회원 × 카테고리 4종)
        </p>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-white">플랫폼별 푸시 토큰 현황</h2>
        <div className="mb-3 flex gap-3 text-sm text-slate-400">
          <span className="rounded-lg border border-slate-800 bg-slate-900 px-3 py-1.5">
            전체 토큰 {pushTokens.length}건
          </span>
          <span className="rounded-lg border border-slate-800 bg-slate-900 px-3 py-1.5">
            토큰 보유 회원 {distinctUsersWithToken}명 / 활성 회원 {totalActiveUsers}명
          </span>
        </div>
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">플랫폼</th>
                <th className="px-4 py-3">토큰 수</th>
                <th className="px-4 py-3">비율</th>
              </tr>
            </thead>
            <tbody>
              {platformStats.map((s) => (
                <tr key={s.platform} className="border-b border-slate-800/60 hover:bg-slate-800/40">
                  <td className="px-4 py-3 text-slate-200">{PLATFORM_LABEL[s.platform]}</td>
                  <td className="px-4 py-3 text-slate-300">{s.count}건</td>
                  <td className="px-4 py-3 text-slate-500">
                    {pushTokens.length > 0
                      ? `${Math.round((s.count / pushTokens.length) * 1000) / 10}%`
                      : "0%"}
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
