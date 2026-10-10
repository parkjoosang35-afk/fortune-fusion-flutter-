import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "복주머니관리"]
// 행복머니(happy-money-products)는 최종 2-자산 구조(프리패스+복주머니)
// 확정에 따라 RewardSubNav 내비게이션에서 이미 링크가 제거되어 있었으나,
// 페이지 자체는 URL 직접 입력으로 여전히 접근 가능한 고립 상태였다. 접근
// 시 /reward/luck-pouch-rules로 리다이렉트한다. HappyMoneyProduct Prisma
// 모델/서버 액션은 전혀 삭제하지 않는다. 원본 UI 코드는 git 히스토리(이
// 커밋 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function HappyMoneyProductsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }
  redirect("/reward/luck-pouch-rules");
}
