import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "프리패스관리"]
// 프리패스는 쿠팡파트너스 전용 4항목(광고이미지/쿠팡파트너스소스/이용시간/
// 대기시간)으로 이미 단순화되어 pass-policies 화면 하나로 통합되었다. 이
// 화면(PassPolicy-Attachment-AdSource N:M 바인딩)은 RewardSubNav 어디에도
// 링크되지 않아 URL 직접 입력으로만 도달 가능한 완전히 고립된 화면이었다.
// 접근 시 /reward/pass-policies로 리다이렉트한다. 관련 Prisma 모델/서버
// 액션은 전혀 삭제하지 않는다. 원본 UI 코드는 git 히스토리(이 커밋 이전
// 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function OpenPassBindingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }
  redirect("/reward/pass-policies");
}
