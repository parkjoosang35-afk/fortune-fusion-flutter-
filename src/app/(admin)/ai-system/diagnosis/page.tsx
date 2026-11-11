import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RunDetectionButton from "@/components/RunDetectionButton";
import SystemDiagnosisRow from "@/components/SystemDiagnosisRow";

// [관리자 2.0 전면 재설계 - Task 11] AI 자동진단 — 3단계(탐지→진단→승인게이트
// 조치) 전체 목록. RBAC는 "ops_system" 재사용(super_admin: RWD, operator: R,
// cs/content_manager: X).
export const dynamic = "force-dynamic";

export default async function AiSystemDiagnosisPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    redirect("/dashboard");
  }
  const canApprove = canWriteMenu(session.roleCode, "ops_system"); // super_admin만 true

  const diagnoses = await prisma.systemDiagnosis.findMany({
    orderBy: { createdAt: "desc" },
    take: 30,
    include: { approvedAdmin: { select: { name: true } } },
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">AI 자동진단</h1>
        <p className="mt-1 text-sm text-slate-500">
          탐지(①) → AI 진단(②) → 승인게이트 조치(③) 3단계로 운영 이상 징후를 점검합니다. 실제 서버 명령은
          자동 실행되지 않으며, 승인 후 운영자가 SSH로 직접 수행합니다(OPERATIONS_POLICY §3).
        </p>
      </div>

      <div className="mb-6">
        <RunDetectionButton />
      </div>

      <section className="space-y-4">
        {diagnoses.length === 0 && (
          <div className="rounded-xl border border-dashed border-slate-300 bg-white/40 p-8 text-center text-sm text-slate-500">
            아직 탐지된 이상 징후가 없습니다. 위 버튼으로 탐지를 실행해보세요.
          </div>
        )}
        {diagnoses.map((d) => (
          <SystemDiagnosisRow
            key={d.id}
            diagnosis={{
              id: d.id,
              category: d.category,
              detectedIssue: d.detectedIssue,
              severity: d.severity,
              diagnosisText: d.diagnosisText,
              suggestedAction: d.suggestedAction,
              status: d.status,
              approvedAdminName: d.approvedAdmin?.name ?? null,
              createdAt: d.createdAt,
            }}
            canDiagnose={canAccessMenu(session.roleCode, "ops_system")}
            canApprove={canApprove}
          />
        ))}
      </section>
    </div>
  );
}
