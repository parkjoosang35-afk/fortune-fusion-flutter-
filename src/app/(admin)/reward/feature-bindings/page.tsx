import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import FeatureAssetBindingRow from "@/components/FeatureAssetBindingRow";

// [열림패스/행복머니/복주머니 통합정책] §5-4/§9-4/§7 관리자 UI 5. 기능-자산 매핑 관리.
// scope/featureGroup/primaryAsset은 읽기 전용(코드 배포로만 변경) — §15 금지 원칙
// "3대 자산 간 스코프 침범 금지"를 관리자 UI 레벨에서도 강제한다.
export const dynamic = "force-dynamic";

const FEATURE_GROUP_LABEL: Record<string, string> = {
  fortune: "운세",
  community: "커뮤니티",
  premium_shop: "프리미엄/상점",
};

export default async function FeatureBindingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;

  const bindings = await prisma.featureAssetBinding.findMany({ orderBy: { scope: "asc" } });

  const grouped = bindings.reduce<Record<string, typeof bindings>>((acc, b) => {
    (acc[b.featureGroup] ??= []).push(b);
    return acc;
  }, {});

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 기능-자산 매핑</h1>
        <p className="mt-1 text-sm text-slate-400">
          화면(FeatureScope)별로 어떤 자산이 필요한지 정의합니다. 앱은 이 매핑을 정책 캐시로
          내려받아 화면별 하드코딩 없이 접근 권한을 판단합니다. scope 구조 자체는 코드 배포로만
          바뀌며, 관리자는 accessType/보조자산/활성여부만 제한적으로 조정할 수 있습니다.
        </p>
      </div>

      <RewardSubNav />

      {Object.entries(grouped).map(([group, items]) => (
        <div key={group} className="mb-6">
          <h2 className="mb-3 text-sm font-semibold text-white">{FEATURE_GROUP_LABEL[group] ?? group}</h2>
          <div className="overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-800 bg-slate-900 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3">scope</th>
                  <th className="px-4 py-3">기능군</th>
                  <th className="px-4 py-3">기본 자산</th>
                  <th className="px-4 py-3">접근 방식</th>
                  <th className="px-4 py-3">상태</th>
                  <th className="px-4 py-3">관리</th>
                </tr>
              </thead>
              <tbody>
                {items.map((binding) => (
                  <FeatureAssetBindingRow key={binding.id} binding={binding} canWrite={canWrite} />
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ))}
    </div>
  );
}
