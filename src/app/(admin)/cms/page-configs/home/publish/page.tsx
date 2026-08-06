import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import PageConfigHomeSubNav from "@/components/PageConfigHomeSubNav";
import PageConfigPublishCenter from "@/components/PageConfigPublishCenter";

// [메인화면 관리자 편집기] §14-7 미리보기/발행센터
// draft-preview / compare-with-live / publish / rollback(=최신 발행으로 즉시 롤백 X,
// 특정 버전 지정 롤백은 §14-8 버전히스토리 화면에서 처리) / scheduled-publish(1차 범위 제외).
export const dynamic = "force-dynamic";

export default async function PageConfigPublishPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "cms")) {
    redirect("/dashboard");
  }
  const canWrite = !!RBAC_MATRIX.cms[session.roleCode as keyof typeof RBAC_MATRIX.cms]?.write;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">미리보기 / 발행센터</h1>
        <p className="mt-1 text-sm text-slate-500">
          draft를 iPhone/Android/Web 비율로 미리 확인하고, 현재 발행(published) 버전과의 차이를
          비교한 뒤 발행합니다. 발행은 draft를 새 버전으로 스냅샷 복제하는 방식이라 과거 버전은
          삭제되지 않고 그대로 보관되어 언제든 되돌릴 수 있습니다.
        </p>
        <PageConfigHomeSubNav />
      </div>
      <PageConfigPublishCenter canWrite={canWrite} />
    </div>
  );
}
