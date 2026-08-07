import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";
import IntroConfigForm from "@/components/IntroConfigForm";

// [인트로 전면 개편] 앱 첫 진입(스플래시+인트로 카드+시작화면) 관리자 설정 화면.
// IntroConfig는 싱글턴 row(id=1)이며, 자유 배치/좌표/애니메이션 수치는 제공하지
// 않고 on-off/문구/이미지/가입보상 수량 등 운영 최소값만 수정 가능하게 한다.
export const dynamic = "force-dynamic";

export default async function IntroConfigPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;

  let config = await prisma.introConfig.findUnique({ where: { id: 1 } });
  if (!config) {
    config = await prisma.introConfig.create({ data: { id: 1 } });
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">인트로(첫 진입) 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          앱 최초 실행 시 노출되는 브랜드 스플래시 · 프리패스/복주머니 안내 카드 ·
          시작 화면(CTA)의 문구와 노출 여부를 관리합니다. 화면 배치와 애니메이션은
          앱 코드에 고정되어 있으며, 여기서는 운영에 필요한 최소 항목만 수정합니다.
        </p>
        <nav className="mt-4 flex flex-wrap gap-2 border-b border-slate-200 text-sm">
          <Link href="/cms/banners" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            배너 관리
          </Link>
          <Link href="/cms/notices" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            공지사항 관리
          </Link>
          <Link href="/cms/faqs" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            FAQ 관리
          </Link>
          <Link href="/cms/events" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            이벤트 관리
          </Link>
          <Link href="/cms/lucky-number" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            오늘의 행운숫자
          </Link>
          <Link href="/cms/healing-quotes" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            힐링 문구
          </Link>
          <Link href="/cms/page-configs/home" className="px-3 py-2 text-slate-500 hover:text-slate-900">
            메인화면 편집
          </Link>
          <Link
            href="/cms/intro-config"
            className="px-3 py-2 font-medium text-slate-900 border-b-2 border-indigo-500"
          >
            인트로 관리
          </Link>
        </nav>
      </div>
      <IntroConfigForm
        canWrite={canWrite}
        row={{
          isEnabled: config.isEnabled,
          showOnlyFirstLaunch: config.showOnlyFirstLaunch,
          showSkipButton: config.showSkipButton,
          showGuestHint: config.showGuestHint,
          splashTitle: config.splashTitle,
          splashSubtitle: config.splashSubtitle,
          card1Title: config.card1Title,
          card1Description: config.card1Description,
          card1ImageUrl: config.card1ImageUrl,
          card2Title: config.card2Title,
          card2Description: config.card2Description,
          card2ImageUrl: config.card2ImageUrl,
          ctaTitle: config.ctaTitle,
          ctaSubtitle: config.ctaSubtitle,
          signupRewardText: config.signupRewardText,
          signupRewardAmount: config.signupRewardAmount,
        }}
      />
    </div>
  );
}
