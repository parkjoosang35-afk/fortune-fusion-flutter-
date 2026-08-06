import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import OpenPassSettingsForm from "@/components/OpenPassSettingsForm";
import BannerCreateForm from "@/components/BannerCreateForm";
import BannerRow from "@/components/BannerRow";
import { getOrCreateOpenPassSettings } from "@/app/actions/pass-policies";

// [프리패스 단순화 - 쿠팡파트너스 전용] §1~§10
// 기존에는 이 화면에서 광고/파트너/구독/이벤트 4종 정책 + 첨부파일/광고소스/
// 상품연결까지 전부 CRUD로 관리했으나(PassPolicyCreateForm/PassPolicyRow),
// "프리패스는 쿠팡 파트너스 광고 전용 기능으로만 운영한다"는 결정에 따라
// 관리자가 만지는 값을 아래 4가지로 줄인다.
//   ① 프리패스 광고 이미지 1장  ② 쿠팡 파트너스 광고 소스(URL/스크립트)
//   ③ 프리패스 이용시간        ④ 광고 확인 대기시간
// ①②는 "CMS 쿠팡파트너스 배너 = 프리패스 광고" 구조에 따라 Banner
// (positionCode='open_pass')를 그대로 재사용하고, 별도의 광고 관리 화면을
// 새로 만들지 않고 이 페이지 안에 바로 임베드한다("하나의 관리 화면").
// ③④는 PassPolicy(passType='ad') 싱글톤 설정으로 관리한다.
//
// [하위 호환] passType='ad' 외 정책(partner/subscription/event)이나 기존
// PassPolicyCreateForm/PassPolicyRow, OpenPassAttachment/AdSource 관련
// 파일/데이터/라우트는 삭제하지 않는다(마이그레이션 drift 회피 + 데이터
// 손실 금지 원칙). 이 화면에서만 노출을 걷어낸다.
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

  // ── 1) 단일 프리패스 설정(이용시간/대기시간) ──
  const settings = await getOrCreateOpenPassSettings();

  // ── 2) 프리패스 광고 배너(CMS 쿠팡파트너스 배너 = 프리패스 광고) ──
  const openPassBanners = await prisma.banner.findMany({
    where: { deletedAt: null, positionCode: "open_pass" },
    orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
  });

  // ── 3) 발급 이력 조회 (단순 where만 사용, 복합쿼리 회피) ──
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

  // ── 4) 요약 통계: 현재 활성중인 패스 수(expiresAt > now) ──
  const activeCount = await prisma.userPass.count({
    where: { expiresAt: { gt: new Date() } },
  });

  const activeBanner = openPassBanners.find((b) => b.isActive);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">리워드 관리 — 프리패스</h1>
        <p className="mt-1 text-sm text-slate-500">
          프리패스는 쿠팡 파트너스 광고 전용 기능으로 운영됩니다. 광고 이미지/쿠팡 광고
          소스는 아래 &quot;프리패스 광고(CMS 배너)&quot; 섹션에서, 이용시간·대기시간은
          &quot;프리패스 설정&quot;에서 관리하며 저장 즉시 앱/웹에 실시간 반영됩니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">현재 활성중인 프리패스</p>
          <p className="mt-2 text-2xl font-bold text-emerald-700">{activeCount.toLocaleString()}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">누적 발급 건수</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{historyTotal.toLocaleString()}</p>
        </div>
      </div>

      {/* ① 프리패스 설정 (이용시간 / 대기시간) */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold text-slate-900">프리패스 설정</h2>
        <OpenPassSettingsForm
          canWrite={canWrite}
          durationMin={settings.durationMin}
          adWaitSeconds={settings.adWaitSeconds}
          isActive={settings.isActive}
          adHelpMessage={settings.adHelpMessage}
          adGuideTitle={settings.adGuideTitle}
          adGuideText={settings.adGuideText}
        />
      </section>

      {/* ② 프리패스 광고 (CMS 쿠팡파트너스 배너 = 프리패스 광고) */}
      <section className="mb-8">
        <h2 className="mb-1 text-lg font-semibold text-slate-900">프리패스 광고 (CMS 쿠팡파트너스 배너)</h2>
        <p className="mb-3 text-xs text-slate-500">
          이미지 1장(썸네일+링크) 또는 쿠팡파트너스 원본 광고 스크립트(iframe) 중 하나를
          등록하세요. 여러 건을 등록해도 활성(노출) 상태인 최신 1건만 프리패스 화면에
          사용됩니다.
          {activeBanner && (
            <span className="ml-1 text-emerald-700">
              현재 적용중: &quot;{activeBanner.title}&quot;
            </span>
          )}
        </p>
        <BannerCreateForm
          canWrite={canWrite}
          fixedPositionCode="open_pass"
          title="새 프리패스 광고 등록"
        />
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">이미지</th>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">노출 위치</th>
                <th className="px-4 py-3">제휴 링크</th>
                <th className="px-4 py-3">노출 기간</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">관리</th>
              </tr>
            </thead>
            <tbody>
              {openPassBanners.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    등록된 프리패스 광고가 없습니다. 위 폼으로 먼저 등록해주세요.
                  </td>
                </tr>
              )}
              {openPassBanners.map((b) => (
                <BannerRow key={b.id} banner={b} canWrite={canWrite} canDelete={canDelete} />
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* ③ 발급 이력 조회 */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">발급 이력 조회</h2>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
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
                  <tr key={h.id} className="border-b border-slate-200/60 hover:bg-slate-100/40">
                    <td className="px-4 py-3 text-slate-500">
                      {h.activatedAt.toISOString().slice(0, 19).replace("T", " ")}
                    </td>
                    <td className="px-4 py-3 text-slate-700">{h.user.nickname}</td>
                    <td className="px-4 py-3 text-slate-600">{h.policy.name}</td>
                    <td className="px-4 py-3 font-mono text-slate-500">{h.sourceType}</td>
                    <td className="px-4 py-3 text-slate-500">
                      {h.expiresAt.toISOString().slice(0, 19).replace("T", " ")}
                    </td>
                    <td className="px-4 py-3">
                      {isActive ? (
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
                          활성중
                        </span>
                      ) : (
                        <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
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
                  p === historyPage ? "bg-indigo-600 text-white" : "text-slate-500 hover:bg-slate-100"
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
