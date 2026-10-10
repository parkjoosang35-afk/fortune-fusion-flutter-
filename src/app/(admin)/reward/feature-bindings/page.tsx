import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [신통방통 관리자 최종 정리 지시서 §3 "복주머니관리"]
// FeatureAssetBinding GET API(/api/public/feature-bindings)는 정상 작동하지만,
// Flutter의 AccessChecker(lib/core/domain/access/access_checker.dart)가 이
// API를 전혀 호출하지 않고 하드코딩된 canEnter() switch문만 사용한다. 즉
// 관리자가 이 화면에서 값을 바꿔도 앱 동작에 전혀 영향이 없는 죽은 연동이다.
// RewardSubNav에서 탭 링크를 제거하고 이 페이지도 접근 시
// /reward/luck-pouch-rules로 리다이렉트한다. FeatureAssetBinding Prisma
// 모델/API는 전혀 삭제하지 않는다. 원본 UI 코드는 git 히스토리(이 커밋
// 이전 버전)에서 복원 가능하다.
export const dynamic = "force-dynamic";

export default async function FeatureBindingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }
  redirect("/reward/luck-pouch-rules");
}
