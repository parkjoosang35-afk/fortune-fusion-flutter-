import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import {
  getEngineRepoInfo,
  hasProductionEngineConfig,
  getConfiguredProductionBaseUrl,
  SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL,
} from "@/lib/saju-engine-admin-client";
import SajuEngineLiveTestPanel from "@/components/SajuEngineLiveTestPanel";

// [2026-11-12 사주엔진관리 신규] saju_engine_deploy(별도 저장소, FastAPI/uvicorn,
// 운영서버 systemd "saju-engine.service"로 상시 구동) 전체를 admin_web에서
// 조회·제한적 테스트할 수 있는 신규 화면.
//
// [구성 — 5개 섹션]
//   1) 엔진 구성 정보(버전/룰파일/모듈/테스트스위트) — 로컬 파일시스템 읽기, 서버 호출 없음
//   2) 운영 엔진 설정 상태 — "설정됨/미설정"만 표시(실제 헬스체크 없음, OPERATIONS_POLICY §10)
//   3) 라이브 테스트 — 로컬/샌드박스 엔진에만 생년월일시 입력해 실계산 결과 확인(별도 클라이언트 컴포넌트)
//   4) 캐시 현황 — SajuFactsCache 테이블 통계(기존 테이블 재사용, 중복 구현 없음)
//   5) 호출 로그/비용 — 기존 AiRequestLog(domain=saju) 링크(중복 구현 없음, /ai-content/logs로 이동)
export const dynamic = "force-dynamic";

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function SajuEngineAdminPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    redirect("/dashboard");
  }

  const repoInfo = getEngineRepoInfo();
  const hasProdConfig = hasProductionEngineConfig();
  const prodBaseUrl = getConfiguredProductionBaseUrl();

  const dayAgo = new Date();
  dayAgo.setDate(dayAgo.getDate() - 1);
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);

  const [
    cacheTotal,
    cacheActive,
    cacheToday,
    cacheWeek,
    recentCacheEntries,
    sajuRequestTotal,
    sajuAiLogsRecent,
    sajuAiLogsFailedRecent,
  ] = await Promise.all([
    prisma.sajuFactsCache.count(),
    prisma.sajuFactsCache.count({ where: { status: "active", deletedAt: null } }),
    prisma.sajuFactsCache.count({ where: { createdAt: { gte: dayAgo } } }),
    prisma.sajuFactsCache.count({ where: { createdAt: { gte: weekAgo } } }),
    prisma.sajuFactsCache.findMany({ orderBy: { createdAt: "desc" }, take: 5 }),
    prisma.fortuneRequest.count({ where: { fortuneType: "saju" } }),
    prisma.aiRequestLog.count({ where: { domain: "saju", createdAt: { gte: dayAgo } } }),
    prisma.aiRequestLog.count({
      where: { domain: "saju", status: { not: "success" }, createdAt: { gte: dayAgo } },
    }),
  ]);

  // [캐시 효율] 전체 사주 요청 중 "엔진 재계산 없이 캐시로 응답한 비율" 근사치 —
  // sajuRequestTotal(FortuneRequest 기준)과 cacheTotal(고유 birthKey 기준)을
  // 직접 1:1 대응시킬 수는 없지만(같은 유저가 여러 번 요청해도 캐시는 1건),
  // "고유 출생정보 대비 재사용 가능 비율"의 참고 지표로 안내문과 함께 표시한다.
  const cacheReuseHint =
    sajuRequestTotal > 0 && cacheTotal > 0
      ? `전체 사주 요청 ${sajuRequestTotal}건 중 고유 출생정보 ${cacheTotal}건만 실제 엔진 계산 — 나머지는 캐시 재사용 가능`
      : null;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">🔮 사주엔진관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          신통방통 정통사주 계산 엔진(saju_engine, 69종 전체 구현, 별도 FastAPI 저장소)의 구성·상태·캐시 현황을
          조회하고, 로컬/샌드박스 엔진에 한해 라이브 테스트를 실행할 수 있습니다. 운영 엔진(systemd
          saju-engine.service)으로는 어떠한 테스트 요청도 보내지 않습니다(OPERATIONS_POLICY §10).
        </p>
      </div>

      {/* ── 1) 엔진 구성 정보 ──────────────────────────────────────── */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">📦 엔진 구성 정보</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">버전</p>
            <p className="mt-2 text-xl font-bold text-slate-900">v3.3</p>
            <p className="mt-1 text-xs text-slate-500">계산 엔진: v3.1 확정본 그대로(v3.2/v3.3은 AI 해석·연동만 추가)</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">정통사주 69종</p>
            <p className="mt-2 text-xl font-bold text-emerald-700">전체 구현</p>
            <p className="mt-1 text-xs text-slate-500">스텁 0건 — 전 항목 data+basis 실계산</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">룰 데이터 파일</p>
            <p className="mt-2 text-xl font-bold text-slate-900">{repoInfo.ruleFiles.length}종</p>
            <p className="mt-1 text-xs text-slate-500">십신·오행·신살·운세 등 JSON 룰</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">테스트 스위트</p>
            <p className="mt-2 text-xl font-bold text-slate-900">{repoInfo.testSuiteDirs.length}개</p>
            <p className="mt-1 text-xs text-slate-500">437항목 + 기존 회귀 전부 통과(납품 기준)</p>
          </div>
        </div>

        <details className="mt-4 rounded-xl border border-slate-200 bg-white p-4">
          <summary className="cursor-pointer text-sm font-medium text-slate-700">
            룰 파일 {repoInfo.ruleFiles.length}종 / 운세 모듈 {repoInfo.moduleFiles.length}종 상세 보기
          </summary>
          <div className="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <p className="mb-2 text-xs font-semibold text-slate-500">룰 파일(rules/)</p>
              <ul className="space-y-1 text-xs text-slate-600">
                {repoInfo.ruleFiles.map((f) => (
                  <li key={f.name} className="flex justify-between border-b border-slate-100 py-1">
                    <span>{f.name}</span>
                    <span className="text-slate-400">{(f.sizeBytes / 1024).toFixed(1)}KB</span>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold text-slate-500">운세 모듈(modules/)</p>
              <ul className="space-y-1 text-xs text-slate-600">
                {repoInfo.moduleFiles.map((f) => (
                  <li key={f.name} className="flex justify-between border-b border-slate-100 py-1">
                    <span>{f.name}</span>
                    <span className="text-slate-400">{(f.sizeBytes / 1024).toFixed(1)}KB</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </details>
      </section>

      {/* ── 2) 운영 엔진 설정 상태 ─────────────────────────────────── */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">🖥 운영 엔진 설정 상태</h2>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-700">
            SAJU_ENGINE_BASE_URL 환경변수:{" "}
            <span className={`font-semibold ${hasProdConfig ? "text-emerald-700" : "text-rose-700"}`}>
              {hasProdConfig ? "설정됨" : "미설정"}
            </span>
          </p>
          {hasProdConfig && (
            <p className="mt-1 font-mono text-xs text-slate-400">
              {prodBaseUrl?.includes("127.0.0.1") || prodBaseUrl?.includes("localhost")
                ? "(내부 주소 — 보안상 상세 비노출, 127.0.0.1 계열 확인됨)"
                : prodBaseUrl}
            </p>
          )}
          <p className="mt-2 text-xs text-amber-700">
            ⚠ 이 화면은 운영 엔진으로 실시간 헬스체크 요청을 보내지 않습니다(OPERATIONS_POLICY §10). 운영 엔진
            실제 가동 여부는 아래 참고 정보로 간접 확인하세요.
          </p>
          <ul className="mt-2 list-disc pl-5 text-xs text-slate-500">
            <li>운영 서버 systemd 서비스명: <code className="font-mono">saju-engine.service</code> (포트 8000, 127.0.0.1 바인딩)</li>
            <li>운영 서버 설치 경로: <code className="font-mono">/opt/saju_engine</code></li>
            <li>LLM 연결: Anthropic 공식 운영키(ANTHROPIC_APP_API_KEY) 재사용, /etc/saju-engine.env로 분리 주입</li>
          </ul>
        </div>
      </section>

      {/* ── 3) 라이브 테스트(로컬/샌드박스 전용) ───────────────────── */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">🧪 라이브 테스트 (로컬/샌드박스 전용)</h2>
        <p className="mb-3 text-xs text-slate-500">
          생년월일시를 입력하면 로컬/샌드박스에서 구동 중인 엔진 인스턴스에 실제 계산을 요청합니다. 운영
          도메인으로는 호출할 수 없도록 코드 레벨에서 차단되어 있습니다.
        </p>
        <SajuEngineLiveTestPanel defaultBaseUrl={SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL} />
      </section>

      {/* ── 4) 캐시 현황 ───────────────────────────────────────────── */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">💾 사주 계산 캐시 현황 (SajuFactsCache)</h2>
        <p className="mb-3 text-xs text-slate-500">
          같은 출생정보는 엔진을 재호출하지 않고 저장된 계산 결과를 재사용합니다(정통사주 리뉴얼 v1.0 §6/§7).
        </p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">전체 캐시</p>
            <p className="mt-2 text-xl font-bold text-slate-900">{cacheTotal.toLocaleString()}건</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">활성 캐시</p>
            <p className="mt-2 text-xl font-bold text-emerald-700">{cacheActive.toLocaleString()}건</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">오늘 신규</p>
            <p className="mt-2 text-xl font-bold text-slate-900">{cacheToday.toLocaleString()}건</p>
          </div>
          <div className="rounded-xl border border-slate-200 bg-white p-4">
            <p className="text-sm text-slate-500">최근 7일 신규</p>
            <p className="mt-2 text-xl font-bold text-slate-900">{cacheWeek.toLocaleString()}건</p>
          </div>
        </div>
        {cacheReuseHint && (
          <p className="mt-3 text-xs text-indigo-700">💡 {cacheReuseHint}</p>
        )}

        <div className="mt-4 overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">생년월일</th>
                <th className="px-4 py-3">출생시각</th>
                <th className="px-4 py-3">음력</th>
                <th className="px-4 py-3">야자시정책</th>
                <th className="px-4 py-3">엔진버전</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">생성 시각</th>
              </tr>
            </thead>
            <tbody>
              {recentCacheEntries.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                    캐시 기록이 없습니다.
                  </td>
                </tr>
              )}
              {recentCacheEntries.map((c) => (
                <tr key={c.id} className="border-b border-slate-200/60">
                  <td className="px-4 py-3 text-slate-700">{c.birthDate}</td>
                  <td className="px-4 py-3 text-slate-500">{c.birthTime ?? "-"}</td>
                  <td className="px-4 py-3 text-slate-500">{c.isLunar ? "음력" : "양력"}</td>
                  <td className="px-4 py-3 text-slate-500">{c.zihourPolicy}</td>
                  <td className="px-4 py-3 text-slate-500">{c.engineVersion}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs ${
                        c.status === "active" ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-500"
                      }`}
                    >
                      {c.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">{fmtDate(c.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* ── 5) 호출 로그/비용 (기존 화면 링크) ─────────────────────── */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">📊 호출 로그/비용 (최근 24시간, domain=saju)</h2>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-slate-500">AI 호출 건수</p>
              <p className="mt-1 text-lg font-bold text-slate-900">{sajuAiLogsRecent.toLocaleString()}건</p>
            </div>
            <div>
              <p className="text-sm text-slate-500">실패 건수</p>
              <p className={`mt-1 text-lg font-bold ${sajuAiLogsFailedRecent > 0 ? "text-rose-700" : "text-slate-900"}`}>
                {sajuAiLogsFailedRecent.toLocaleString()}건
              </p>
            </div>
          </div>
          <Link href="/ai-content/logs" className="mt-3 inline-block text-xs text-indigo-700 hover:underline">
            전체 AI 호출 로그/비용 대시보드로 이동 →
          </Link>
        </div>
      </section>
    </div>
  );
}
