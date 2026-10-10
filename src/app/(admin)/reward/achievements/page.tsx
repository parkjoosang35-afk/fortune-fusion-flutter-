import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "복주머니관리"]
// Achievement(업적)에 대응하는 공개 API(/api/public/achievements 등)가
// 전혀 없고, Flutter 앱(lib/) 전체에서도 achievement 관련 코드가 0건 —
// 운영자가 업적을 등록해도 앱에서 지급/달성시킬 방법 자체가 없는 완전히
// 도달 불가능한 화면이다. RewardSubNav에서 탭 링크를 제거하고 이 페이지도
// 접근 시 /reward/luck-pouch-rules로 리다이렉트한다. Achievement/
// UserAchievement Prisma 모델과 데이터는 전혀 삭제하지 않는다
// (account-purge.ts가 UserAchievement를 참조하므로 보존 필요). 원본 UI
// 코드는 git 히스토리(이 커밋 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function RewardAchievementsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }
  redirect("/reward/luck-pouch-rules");
}
