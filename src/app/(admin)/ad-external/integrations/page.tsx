import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [관리자 2.0 전면 재설계 - Task 10] 광고외부연동 — 외부 서비스 연동 현황 매트릭스.
//
// [RBAC] rbac.ts 주석 결정에 따라 "ad_management" 코드 재사용(reward 미러링).
//
// [범위/설계 결정 — 조회 전용, 실제 네트워크 호출 없음] OPERATIONS_POLICY §10은
// 프로덕션 서버로의 테스트 트래픽을 금지한다. 이 화면은 "실제로 API를 호출해
// 살아있는지(health check)"를 검증하지 않고, 대신 (1) 서버 환경변수 존재 여부,
// (2) DB(AdPlatformConfig)에 이미 저장된 설정값, (3) 코드베이스에 하드코딩된
// 실 식별자(App ID 등) 존재 여부 — 이 3가지 "설정 존재" 신호만으로 연동 상태를
// 판정한다(실제 API 쿼터를 소모하거나 프로덕션에 요청을 보내지 않음). 값 자체
// (API 키 등)는 노출하지 않고 "설정됨/미설정" 배지만 표시한다.
//
// [전수조사 근거 — 보고서③/④ + 이번 턴 grep 조사]
//   - AdMob: Flutter lib/features/ads_test/domain/admob_ad_ids.dart에 실
//     App ID/Ad Unit ID가 하드코딩되어 있고, --dart-define=ADMOB_USE_REAL_IDS
//     플래그로만 실ID 전환(기본 false=테스트ID). DB AdPlatformConfig.admob
//     행은 "노출 킬스위치"만 담당(실ID 전환과 무관). 두 신호를 함께 보여준다.
//   - AdSense: DB AdPlatformConfig.adsense.publisherId(ca-pub-...) 존재 여부로
//     판정 — 이미 /reward/fortune-ads(AdsenseConfigCard)에서 설정 가능.
//   - Google Play: 전수조사 결과(보고서④) in_app_purchase/billing 관련 코드가
//     코드베이스에 전혀 없음 — 100% 미연동으로 명시한다(혼동 방지).
//   - Kakao: Flutter core/config/social_auth_config.dart에 kakaoNativeAppKey가
//     하드코딩되어 있고, admin_web social-auth-verify.ts가 kapi.kakao.com으로
//     실제 토큰 검증 요청을 보낸다(로그인 시에만, 이 화면에서 호출 안 함).
//   - Anthropic: admin_web .env의 ANTHROPIC_APP_API_KEY 존재 여부(llm-client.ts
//     가 실제로 사용 중 — AI 운세 해석).
//   - OpenAI: admin_web .env의 BOKJU_AI_IMAGE_API_KEY 존재 여부(쿠폰 디자인
//     배경 생성용, bokju-coupon-ai-background-client.ts가 실제 사용 중).
export const dynamic = "force-dynamic";

type Status = "connected" | "partial" | "disconnected";

interface IntegrationRow {
  key: string;
  name: string;
  category: string;
  status: Status;
  detail: string;
  manageHref: string;
  manageLabel: string;
}

function StatusBadge({ status }: { status: Status }) {
  const cls =
    status === "connected"
      ? "bg-emerald-100 text-emerald-700"
      : status === "partial"
        ? "bg-amber-100 text-amber-700"
        : "bg-slate-100 text-slate-500";
  const label = status === "connected" ? "연동됨" : status === "partial" ? "부분 연동" : "미연동";
  return <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${cls}`}>{label}</span>;
}

export default async function AdExternalIntegrationsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ad_management")) {
    redirect("/dashboard");
  }

  const [admobConfig, adsenseConfig] = await Promise.all([
    prisma.adPlatformConfig.findUnique({ where: { platform: "admob" } }),
    prisma.adPlatformConfig.findUnique({ where: { platform: "adsense" } }),
  ]);

  const hasAnthropicKey = !!process.env.ANTHROPIC_APP_API_KEY || !!process.env.ANTHROPIC_API_KEY;
  const hasOpenAiKey = !!process.env.BOKJU_AI_IMAGE_API_KEY;
  const hasGoogleOAuth = !!process.env.GOOGLE_OAUTH_WEB_CLIENT_ID;
  // [하드코딩 확인 — 이번 턴 grep 조사 근거] 실제 값을 서버에서 다시 읽어오지
  // 않고(Flutter 코드는 admin_web 프로세스와 별도 배포물이라 import 불가),
  // 전수조사로 이미 확인된 사실을 상수로 반영한다. 코드가 바뀌면 이 상수도
  // 함께 갱신해야 한다(권한 소스 이원화와 유사한 한계 — 자동 동기화 아님).
  const admobHasRealIdHardcoded = true; // admob_ad_ids.dart: _realAppId/_realBannerId 등 하드코딩 확인됨
  const kakaoHasNativeKeyHardcoded = true; // social_auth_config.dart: kakaoNativeAppKey 하드코딩 확인됨

  const rows: IntegrationRow[] = [
    {
      key: "admob",
      name: "AdMob",
      category: "앱 리워드/배너 광고",
      status: admobConfig?.isEnabled && admobHasRealIdHardcoded ? "connected" : admobHasRealIdHardcoded ? "partial" : "disconnected",
      detail: admobHasRealIdHardcoded
        ? `실 App ID 등록됨 · 노출 킬스위치: ${admobConfig?.isEnabled ? "ON" : "OFF"} · 실ID 전환은 빌드 플래그(ADMOB_USE_REAL_IDS)로 별도 제어`
        : "실 Ad Unit ID 미등록",
      manageHref: "/reward/fortune-ads",
      manageLabel: "AdMob 설정 관리 →",
    },
    {
      key: "adsense",
      name: "AdSense",
      category: "웹 광고",
      status: adsenseConfig?.isEnabled && adsenseConfig?.publisherId ? "connected" : adsenseConfig?.publisherId ? "partial" : "disconnected",
      detail: adsenseConfig?.publisherId
        ? `퍼블리셔 ID 등록됨 · 노출: ${adsenseConfig.isEnabled ? "ON" : "OFF"}`
        : "퍼블리셔 ID 미등록(승인 대기 또는 설정 전)",
      manageHref: "/reward/fortune-ads",
      manageLabel: "AdSense 설정 관리 →",
    },
    {
      key: "google_play",
      name: "Google Play(인앱결제)",
      category: "결제",
      status: "disconnected",
      detail: "전수조사 결과 in_app_purchase/billing 연동 코드 없음 — 미연동 확정",
      manageHref: "/payments/plans",
      manageLabel: "결제/구독(정책준비중) →",
    },
    {
      key: "kakao",
      name: "Kakao",
      category: "소셜 로그인",
      status: kakaoHasNativeKeyHardcoded ? "connected" : "disconnected",
      detail: kakaoHasNativeKeyHardcoded
        ? "네이티브 앱 키 등록됨 · kapi.kakao.com 토큰 검증 연동 중"
        : "앱 키 미등록",
      manageHref: "/users",
      manageLabel: "회원·이용내역(소셜 가입자) →",
    },
    {
      key: "google_oauth",
      name: "Google OAuth",
      category: "소셜 로그인",
      status: hasGoogleOAuth ? "connected" : "disconnected",
      detail: hasGoogleOAuth ? "웹 클라이언트 ID 등록됨" : "클라이언트 ID 미등록",
      manageHref: "/users",
      manageLabel: "회원·이용내역(소셜 가입자) →",
    },
    {
      key: "anthropic",
      name: "Anthropic (Claude)",
      category: "AI 엔진",
      status: hasAnthropicKey ? "connected" : "disconnected",
      detail: hasAnthropicKey ? "API 키 등록됨 · AI 운세 해석에 사용 중" : "API 키 미등록",
      manageHref: "/ai-content/logs",
      manageLabel: "AI 호출 로그/비용 →",
    },
    {
      key: "openai",
      name: "OpenAI",
      category: "AI 엔진",
      status: hasOpenAiKey ? "connected" : "disconnected",
      detail: hasOpenAiKey ? "API 키 등록됨 · 복주머니 쿠폰 배경 생성(gpt-image-1)에 사용 중" : "API 키 미등록",
      manageHref: "/bokju-coupons/design-templates",
      manageLabel: "쿠폰 디자인 템플릿 →",
    },
    {
      key: "firebase",
      name: "Firebase",
      category: "백엔드/푸시",
      status: "disconnected",
      detail: "보고서④ 확정 사항: 현재 완전히 미사용(코드/설정 없음)",
      manageHref: "/system-settings",
      manageLabel: "전역 설정값 →",
    },
  ];

  const connectedCount = rows.filter((r) => r.status === "connected").length;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">광고외부연동 — 외부서비스 연동 현황</h1>
        <p className="mt-1 text-sm text-slate-500">
          서버 환경변수/DB 설정/코드 내 식별자 등록 여부만으로 판정하는 조회 전용 현황판입니다
          (운영 서버로 실제 API 호출은 하지 않습니다 — OPERATIONS_POLICY §10). 연동됨({connectedCount}/{rows.length})
        </p>
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">서비스</th>
                <th className="px-4 py-3">분류</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">상세</th>
                <th className="px-4 py-3">바로가기</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.key} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                  <td className="px-4 py-3 font-medium text-slate-800">{r.name}</td>
                  <td className="px-4 py-3 text-slate-500">{r.category}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={r.status} />
                  </td>
                  <td className="px-4 py-3 text-xs text-slate-500">{r.detail}</td>
                  <td className="px-4 py-3">
                    <Link href={r.manageHref} className="text-xs text-indigo-700 hover:underline">
                      {r.manageLabel}
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <p className="mt-4 text-xs text-slate-600">
          ⚠️ "연동됨"은 설정값이 등록되어 있다는 의미일 뿐, 실제 API가 정상 응답하는지(쿼터/네트워크 상태)는
          보증하지 않습니다. 운영 서버에 대한 실시간 헬스체크는 정책상(§10) 수행하지 않습니다.
        </p>
      </section>
    </div>
  );
}
