import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "프리패스관리"]
// open-pass-bindings/page.tsx와 동일한 사유 — RewardSubNav 어디에도
// 링크되지 않은 완전 고립 화면. 프리패스는 쿠팡파트너스 전용 4항목으로
// pass-policies 화면 하나에 통합되었다. 접근 시 /reward/pass-policies로
// 리다이렉트한다. OpenPassAdSource Prisma 모델/서버 액션은 보존한다.
// 원본 UI 코드는 git 히스토리(이 커밋 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function OpenPassAdSourcesPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }
  redirect("/reward/pass-policies");
}
