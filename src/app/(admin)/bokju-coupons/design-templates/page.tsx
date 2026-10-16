import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";
import BokjuDesignTemplateManager from "@/components/BokjuDesignTemplateManager";

// [신통방통 AI 쿠폰 디자인 표시·숨김 기능] 관리자가 AI로 쿠폰 배경을 요청하고,
// 11개 정보 항목의 표시/숨김을 자유롭게 조합해 실시간 미리보기를 확인한 뒤
// "디자인 템플릿"으로 저장하는 화면. 저장된 템플릿은 "쿠폰 만들기" 화면의
// 디자인 선택 목록에 나타난다(캠페인 생성 폼과는 별개 화면으로 분리해,
// 디자인 준비와 캠페인 발행을 독립적으로 작업할 수 있게 한다).
export const dynamic = "force-dynamic";

export default async function BokjuDesignTemplatesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.bokju_coupon[session.roleCode as keyof typeof RBAC_MATRIX.bokju_coupon]?.write;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">AI 쿠폰 디자인 — 배경 생성 · 표시 설정 · 템플릿 관리</h1>
        <p className="mt-1 text-sm text-slate-500">
          AI에게 문구로 배경을 요청하고, 쿠폰 이미지에 표시할 정보 11개 항목을 자유롭게 선택한 뒤
          실시간 미리보기로 확인하고 템플릿으로 저장합니다. 저장된 템플릿은 쿠폰 만들기 화면에서
          선택해 실제 발행 이미지에 적용할 수 있습니다. QR코드·쿠폰번호·만료일을 이미지에서
          숨기더라도 실제 서버 검증·등록·복주머니 지급 기능은 항상 그대로 동작합니다.
        </p>
      </div>

      <BokjuCouponSubNav />

      <BokjuDesignTemplateManager canWrite={canWrite} />
    </div>
  );
}
