// [쿠폰 디자인 스튜디오 4단계 — 작업순서3] 서버 컴포넌트
// /bokju-coupons/campaigns/:id/design
//
// 이 페이지는 인증·권한 체크 + 캠페인 요약 데이터 조회만 담당하고,
// 실제 에디터 UI는 전부 BokjuCouponDesignStudio.tsx("use client")에
// 위임한다(campaigns/[id]/page.tsx와 동일한 기존 관행).
//
// [§4-3 범위 경계] 이 라우트를 만드는 것 자체는 작업순서3 범위다. 기존
// 캠페인 상세 화면(campaigns/[id]/page.tsx)에 "신규 디자인으로 전환" 버튼을
// 추가하는 것은 작업순서4(§4-3)의 몫이므로 이번 파일에서는 건드리지 않는다
// — 지금은 URL을 직접 열어 접근한다.
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuCouponDesignStudio from "@/components/BokjuCouponDesignStudio";

export const dynamic = "force-dynamic";

export default async function BokjuCampaignDesignPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) redirect("/dashboard");
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) notFound();

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
  if (!campaign) notFound();

  return (
    <div>
      <Link href={`/bokju-coupons/campaigns/${campaignId}`} className="text-sm text-indigo-600 hover:underline">
        ← 캠페인 상세로
      </Link>
      <BokjuCouponSubNav />
      <div className="mt-4">
        <h1 className="text-xl font-bold text-slate-900">쿠폰 디자인 스튜디오 — {campaign.title}</h1>
        <p className="mt-1 text-sm text-slate-500">
          배치·색·부품을 자유롭게 구성합니다. 미리보기의 QR·쿠폰번호는 전부 샘플 값이며, 실제
          발행 이미지에는 각 쿠폰의 진짜 QR·번호가 들어갑니다.
        </p>
      </div>
      <BokjuCouponDesignStudio
        campaignId={campaignId}
        canWrite={canWrite}
        campaign={{
          title: campaign.title,
          grantAmount: campaign.grantAmount,
          guideText: campaign.guideText,
          validFrom: campaign.validFrom.toISOString(),
          validTo: campaign.validTo.toISOString(),
        }}
      />
    </div>
  );
}
