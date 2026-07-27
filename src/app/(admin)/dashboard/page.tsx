import { verifyAdminSession } from "@/lib/dal";
import { prisma } from "@/lib/db";
import Link from "next/link";

// 05_Admin_System_Design.md §3.0 "대시보드" — 라이브 운영센터 + 통계 대시보드 2단 구성
// Phase18-Dashboard 1차 소단위: 기존 04A 테이블(luckybag_open_logs/user_amulets/
// giftcard_issues/wishes/matching_pairs/reports/error_logs/payments/point_histories/
// statistics_snapshots/ai_request_logs)만으로 산출 가능한 위젯을 우선 구현한다.
// Phase18-Dashboard 2차 소단위(FortuneCore-1 후속): 04A E-1(fortune_requests) 테이블이
//   신규 추가되어, 🟢"지금 운세 보는 사람 수" 위젯을 fortune_requests.status="pending"
//   카운트로 해소한다(요청 접수~AI응답 완료 전까지의 상태를 seed_fortune_core.ts에서
//   금일 요청의 8%를 의도적으로 pending으로 시딩해 시연 가능하도록 구성함).
// Phase18-Dashboard 3차 소단위(Consultation-1 후속): 04A G-1(consultation_sessions)
//   테이블이 신규 추가되어, 💬"AI 상담 진행 건수" 위젯을 consultation_sessions
//   WHERE ended_at IS NULL 카운트로 해소한다(05§3.0.1 명시 산출 방식 그대로 적용).
//   05§3.0.1 원문상 🟢 위젯의 데이터 소스는 fortune_requests + consultation_sessions
//   (ended_at IS NULL) 두 테이블 합산으로 정의되어 있으므로, 🟢 위젯도 두 값의 합으로
//   보정한다(💬 위젯과 데이터가 일부 중복되나, 05문서가 명시한 산출 방식 그대로임).
// [범위 결정] §3.0.1의 10종 위젯 중 🔴현재 접속자 수(신규 실시간 세션 캐시 필요) 1종만
//   이번 소단위에서도 데이터 소스가 없어 구현 불가하다. 화면 깨짐 방지 및 투명성을 위해
//   "준비 중" 배지로 명시하고, 8절의 Redis 캐시 계층 도입 시 후속 구현한다. 나머지
//   9종은 기존 인덱스(created_at/status)만으로 당일분 카운트/합계 쿼리이므로 신규
//   인덱스 없이 그대로 구현한다.
// [RBAC] §3.0.1 권한: super_admin/operator는 전체 위젯, cs/content_manager는
//   매출·리워드 관련 위젯(🎁🎟📈)을 비노출 — RBAC_MATRIX.dashboard 자체는 4역할
//   모두 read=true이므로, 위젯 단위 세부 노출은 이 페이지 내부에서 역할코드로 분기한다.
export const dynamic = "force-dynamic";

const METRIC_LABEL: Record<string, string> = {
  dau: "일간 활성 사용자(DAU)",
  point_issued_daily: "일간 포인트 지급량",
  revenue_daily: "일간 결제 매출",
  new_signup_daily: "일간 신규 가입자",
};

const AI_DOMAIN_LABEL: Record<string, string> = {
  saju: "사주풀이",
  daily: "오늘의 운세",
  tarot: "타로",
  face: "관상",
  palm: "손금",
  consultation: "AI 상담",
};

function todayStart(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function parseSnapshotValue(jsonValue: string): number {
  try {
    const parsed = JSON.parse(jsonValue) as Record<string, unknown>;
    const first = Object.values(parsed)[0];
    return typeof first === "number" ? first : 0;
  } catch {
    return 0;
  }
}

export default async function DashboardPage() {
  const session = await verifyAdminSession();
  const canSeeRevenue = session.roleCode === "super_admin" || session.roleCode === "operator";
  const today = todayStart();
  const dayAgo = new Date();
  dayAgo.setDate(dayAgo.getDate() - 1);

  const [
    luckybagToday,
    amuletToday,
    giftcardToday,
    wishToday,
    matchingToday,
    reportsPending,
    errorCritical24h,
    paymentsToday,
    pointHistoryToday,
    snapshots14d,
    aiLogsToday,
    fortuneRequestsPending,
    consultationOngoing,
  ] = await Promise.all([
    prisma.luckybagOpenLog.count({ where: { createdAt: { gte: today }, status: "completed" } }),
    prisma.userAmulet.count({ where: { acquiredAt: { gte: today } } }),
    prisma.giftcardIssue.count({ where: { issuedAt: { gte: today }, status: "issued" } }),
    prisma.wish.count({ where: { createdAt: { gte: today } } }),
    prisma.matchingPair.count({ where: { matchedAt: { gte: today }, status: "active" } }),
    prisma.report.count({ where: { status: "pending" } }),
    prisma.errorLog.count({ where: { severity: "critical", createdAt: { gte: dayAgo } } }),
    prisma.payment.findMany({ where: { status: "paid", createdAt: { gte: today } }, select: { amount: true } }),
    prisma.pointHistory.findMany({ where: { createdAt: { gte: today } }, select: { amount: true, type: true } }),
    prisma.statisticsSnapshot.findMany({
      where: { deletedAt: null, metricCode: { in: Object.keys(METRIC_LABEL) } },
      orderBy: { period: "desc" },
    }),
    prisma.aiRequestLog.findMany({ where: { createdAt: { gte: today } }, select: { domain: true, costEstimate: true } }),
    prisma.fortuneRequest.count({ where: { status: "pending" } }),
    prisma.consultationSession.count({ where: { endedAt: null } }),
  ]);

  // [운세 앱 개발 프롬프트-Task3] 대시보드에서 "광고 배너 현황"을 한눈에 보고
  // CMS 배너 관리로 바로 이동할 수 있게 하는 요약 위젯용 집계.
  const bannerPositions = ["home_top", "home_middle", "home_bottom"] as const;
  const bannerRows = await prisma.banner.findMany({
    where: { deletedAt: null },
    select: { positionCode: true, isActive: true },
  });
  const bannerSummary = bannerPositions.map((positionCode) => {
    const inPosition = bannerRows.filter((b) => b.positionCode === positionCode);
    return {
      positionCode,
      total: inPosition.length,
      active: inPosition.filter((b) => b.isActive).length,
    };
  });

  // 05§3.0.1 🟢 위젯 산출 방식: fortune_requests(pending) + consultation_sessions(진행중) 합산
  const nowViewingFortuneCount = fortuneRequestsPending + consultationOngoing;

  const revenueToday = paymentsToday.reduce((s, p) => s + p.amount, 0);
  const pointEarnedToday = pointHistoryToday.filter((h) => h.type === "earn").reduce((s, h) => s + h.amount, 0);
  const pointSpentToday = pointHistoryToday
    .filter((h) => h.type === "spend")
    .reduce((s, h) => s + Math.abs(h.amount), 0);

  // 통계 대시보드용: metric_code별 최신 2개(오늘/전일) 비교로 추이 배지 산출
  const trendByMetric = Object.keys(METRIC_LABEL).map((code) => {
    const items = snapshots14d.filter((s) => s.metricCode === code);
    const latest = items[0];
    const prev = items[1];
    const latestVal = latest ? parseSnapshotValue(latest.value) : 0;
    const prevVal = prev ? parseSnapshotValue(prev.value) : 0;
    const diff = latestVal - prevVal;
    return { code, latest, latestVal, diff };
  });

  const aiDomainCounts = new Map<string, number>();
  let aiCostToday = 0;
  for (const log of aiLogsToday) {
    aiDomainCounts.set(log.domain, (aiDomainCounts.get(log.domain) ?? 0) + 1);
    aiCostToday += log.costEstimate ?? 0;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">대시보드</h1>
        <p className="mt-1 text-sm text-slate-400">
          {session.name}님, 환영합니다 ({session.roleCode})
        </p>
      </div>

      {/* ① 라이브 운영센터 */}
      <section className="mb-10">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">🔴 라이브 운영센터</h2>
          <span className="text-xs text-slate-500">페이지 새로고침 시 최신값 조회(폴백: 쿼리 기반, P1)</span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {/* 준비 중 위젯 1종 — 데이터 소스 부재(신규 실시간 세션 캐시) */}
          <div className="rounded-xl border border-dashed border-slate-700 bg-slate-900/40 p-4">
            <p className="text-sm text-slate-500">🔴 현재 접속자 수</p>
            <p className="mt-2 text-xs text-amber-400">준비 중 — 실시간 세션 캐시 인프라 필요</p>
          </div>

          {/* 지금 운세 보는 사람 수 — fortune_requests.pending + consultation_sessions(진행중) 합산 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🟢 지금 운세 보는 사람 수</p>
            <p className="mt-2 text-2xl font-bold text-white">{nowViewingFortuneCount.toLocaleString()}명</p>
          </div>

          {/* AI 상담 진행 건수 — consultation_sessions WHERE ended_at IS NULL */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">💬 AI 상담 진행 건수</p>
            <p className="mt-2 text-2xl font-bold text-white">{consultationOngoing.toLocaleString()}건</p>
          </div>

          {/* 오늘 발급된 디지털 부적 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🧧 오늘 발급된 디지털 부적</p>
            <p className="mt-2 text-2xl font-bold text-white">{amuletToday.toLocaleString()}건</p>
          </div>

          {/* 오늘 지급된 복주머니 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🎁 오늘 지급된 복주머니</p>
            {canSeeRevenue ? (
              <p className="mt-2 text-2xl font-bold text-white">{luckybagToday.toLocaleString()}건</p>
            ) : (
              <p className="mt-2 text-xs text-slate-500">권한 없음(리워드 위젯 비노출)</p>
            )}
          </div>

          {/* 오늘 교환된 상품권 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🎟 오늘 교환된 상품권</p>
            {canSeeRevenue ? (
              <p className="mt-2 text-2xl font-bold text-white">{giftcardToday.toLocaleString()}건</p>
            ) : (
              <p className="mt-2 text-xs text-slate-500">권한 없음(리워드 위젯 비노출)</p>
            )}
          </div>

          {/* 오늘 작성된 소원 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">❤️ 오늘 작성된 소원</p>
            <p className="mt-2 text-2xl font-bold text-white">{wishToday.toLocaleString()}건</p>
          </div>

          {/* 오늘 성사된 궁합 매칭 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="text-sm text-slate-400">🤝 오늘 성사된 궁합 매칭</p>
            <p className="mt-2 text-2xl font-bold text-white">{matchingToday.toLocaleString()}건</p>
          </div>

          {/* 신고 및 이상 징후 */}
          <Link
            href="/community/reports"
            className="rounded-xl border border-slate-800 bg-slate-900 p-4 transition hover:border-rose-800 hover:bg-rose-950/10"
          >
            <p className="text-sm text-slate-400">🚨 신고 및 이상 징후</p>
            <p className="mt-2 text-2xl font-bold text-white">
              {reportsPending.toLocaleString()}
              <span className="ml-1 text-sm text-slate-500">건 미처리</span>
            </p>
            <p className="mt-1 text-xs text-rose-400">24시간 내 심각 에러 {errorCritical24h.toLocaleString()}건</p>
          </Link>

          {/* 실시간 매출 및 리워드 현황 */}
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4 sm:col-span-2">
            <p className="text-sm text-slate-400">📈 실시간 매출 및 리워드 현황</p>
            {canSeeRevenue ? (
              <div className="mt-2 flex flex-wrap gap-6">
                <div>
                  <p className="text-xs text-slate-500">금일 결제 매출</p>
                  <p className="text-xl font-bold text-white">{revenueToday.toLocaleString()}원</p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">금일 포인트 발행</p>
                  <p className="text-xl font-bold text-emerald-400">+{pointEarnedToday.toLocaleString()}P</p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">금일 포인트 소진</p>
                  <p className="text-xl font-bold text-amber-400">-{pointSpentToday.toLocaleString()}P</p>
                </div>
              </div>
            ) : (
              <p className="mt-2 text-xs text-slate-500">권한 없음(매출 위젯 비노출)</p>
            )}
          </div>
        </div>
      </section>

      {/* [운세 앱 개발 프롬프트-Task3] 광고 배너 현황 요약 — CMS 배너 관리로 바로 이동 */}
      <section className="mb-10">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">📢 광고 배너 현황</h2>
          <Link href="/cms/banners" className="text-xs text-indigo-400 hover:underline">
            배너 관리로 이동 →
          </Link>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {bannerSummary.map((s) => {
            const label =
              s.positionCode === "home_top"
                ? "홈 상단"
                : s.positionCode === "home_middle"
                  ? "홈 중단"
                  : "홈 하단";
            const allActive = s.total > 0 && s.active === s.total;
            const noneActive = s.active === 0;
            return (
              <Link
                key={s.positionCode}
                href="/cms/banners"
                className="rounded-xl border border-slate-800 bg-slate-900 p-4 transition hover:border-indigo-800 hover:bg-indigo-950/10"
              >
                <div className="flex items-center justify-between">
                  <p className="text-sm text-slate-400">{label}</p>
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
                      s.total === 0
                        ? "bg-slate-800 text-slate-400"
                        : allActive
                          ? "bg-emerald-950/60 text-emerald-400"
                          : noneActive
                            ? "bg-slate-800 text-slate-400"
                            : "bg-amber-950/60 text-amber-400"
                    }`}
                  >
                    {s.total === 0 ? "배너 없음" : allActive ? "노출중" : noneActive ? "비노출" : "일부 노출"}
                  </span>
                </div>
                <p className="mt-2 text-xl font-bold text-white">
                  {s.active}
                  <span className="text-sm font-normal text-slate-500"> / {s.total}건 활성</span>
                </p>
              </Link>
            );
          })}
        </div>
      </section>

      {/* ② 통계 대시보드 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-white">📊 통계 대시보드</h2>

        {errorCritical24h > 0 && (
          <div className="mb-4 rounded-lg border border-rose-900 bg-rose-950/30 px-4 py-3 text-sm text-rose-300">
            ⚠ 최근 24시간 내 심각(critical) 에러 {errorCritical24h}건 발생 —{" "}
            <Link href="/system-settings/logs" className="underline">
              로그 확인하기
            </Link>
          </div>
        )}

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {trendByMetric.map(({ code, latest, latestVal, diff }) => {
            if ((code === "revenue_daily" || code === "point_issued_daily") && !canSeeRevenue) {
              return (
                <div key={code} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
                  <p className="text-sm text-slate-400">{METRIC_LABEL[code]}</p>
                  <p className="mt-2 text-xs text-slate-500">권한 없음(매출 관련 위젯 비노출)</p>
                </div>
              );
            }
            return (
              <div key={code} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
                <p className="text-sm text-slate-400">{METRIC_LABEL[code]}</p>
                <p className="mt-2 text-2xl font-bold text-white">
                  {latestVal.toLocaleString()}
                  {diff !== 0 && (
                    <span className={`ml-2 text-sm font-normal ${diff > 0 ? "text-emerald-400" : "text-rose-400"}`}>
                      {diff > 0 ? "▲" : "▼"}
                      {Math.abs(diff).toLocaleString()}
                    </span>
                  )}
                </p>
                <p className="mt-1 text-xs text-slate-500">
                  {latest ? `기준일: ${latest.period}` : "데이터 없음"}
                </p>
              </div>
            );
          })}
        </div>

        {/* AI 호출량(기능별) */}
        <div className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <p className="mb-3 text-sm font-medium text-slate-300">금일 AI 호출량(기능별)</p>
          {aiDomainCounts.size === 0 ? (
            <p className="text-sm text-slate-500">금일 AI 호출 로그가 없습니다.</p>
          ) : (
            <div className="flex flex-wrap gap-4">
              {[...aiDomainCounts.entries()].map(([domain, count]) => (
                <div key={domain} className="rounded-lg bg-slate-800/60 px-3 py-2">
                  <p className="text-xs text-slate-400">{AI_DOMAIN_LABEL[domain] ?? domain}</p>
                  <p className="text-lg font-bold text-white">{count.toLocaleString()}회</p>
                </div>
              ))}
              {canSeeRevenue && (
                <div className="rounded-lg bg-slate-800/60 px-3 py-2">
                  <p className="text-xs text-slate-400">예상 비용 합계</p>
                  <p className="text-lg font-bold text-indigo-300">${aiCostToday.toFixed(4)}</p>
                </div>
              )}
            </div>
          )}
          <Link href="/ai-content/logs" className="mt-3 inline-block text-xs text-indigo-400 hover:underline">
            AI 호출 로그 상세 보기 →
          </Link>
        </div>

        <p className="mt-4 text-xs text-slate-600">
          지표 원본은 배치 집계(statistics_snapshots) 기준이며, 실시간 값과는 최대 1일 지연이 있을 수 있습니다.
        </p>
      </section>
    </div>
  );
}
