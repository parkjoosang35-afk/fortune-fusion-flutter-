"use client";

// [관리자 2.0 전면 재설계 - Task 11] AI 자동진단 — 단계별 액션 버튼(진단 실행/
// 승인/반려). ReportRow.tsx의 useActionState 패턴 재사용.
//
// [05§1 원칙7] 승인은 "조치를 실행"하는 것이 아니라 "운영자가 직접 하겠다는
// 의사결정 기록"일 뿐이라 위험 조작(환불/계정정지 등)과 성격이 다르지만,
// 되돌리기 번거로운 결정이므로 ConfirmDangerDialog 수준은 아니어도 승인 버튼은
// diagnosed 상태에서만 노출해 실수 클릭을 줄인다.
import { useActionState } from "react";
import {
  runDiagnosis,
  approveDiagnosisAction,
  rejectDiagnosisAction,
  type DiagnosisFormState,
} from "@/app/actions/system-diagnosis";

interface SystemDiagnosisRowProps {
  diagnosis: {
    id: number;
    category: string;
    detectedIssue: string;
    severity: string;
    diagnosisText: string | null;
    suggestedAction: string | null;
    status: string; // detected/diagnosed/approved/rejected
    approvedAdminName: string | null;
    createdAt: Date;
  };
  canDiagnose: boolean; // ops_system read 권한(탐지/진단 실행)
  canApprove: boolean; // ops_system write 권한(super_admin만 — 승인/반려)
}

const initialState: DiagnosisFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  detected: { label: "① 탐지됨", cls: "bg-amber-100 text-amber-700" },
  diagnosed: { label: "② 진단완료", cls: "bg-indigo-100 text-indigo-700" },
  approved: { label: "③ 승인(조치 대기)", cls: "bg-emerald-100 text-emerald-700" },
  rejected: { label: "반려됨", cls: "bg-slate-100 text-slate-500" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function SystemDiagnosisRow({ diagnosis, canDiagnose, canApprove }: SystemDiagnosisRowProps) {
  const [diagnoseState, diagnoseAction, diagnosePending] = useActionState(runDiagnosis, initialState);
  const [approveState, approveFormAction, approvePending] = useActionState(approveDiagnosisAction, initialState);
  const [rejectState, rejectFormAction, rejectPending] = useActionState(rejectDiagnosisAction, initialState);

  const st = STATUS_LABEL[diagnosis.status] ?? { label: diagnosis.status, cls: "bg-white text-slate-500" };

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${st.cls}`}>{st.label}</span>
          <span className="ml-2 text-xs text-slate-500">{diagnosis.category} · {fmtDate(diagnosis.createdAt)}</span>
        </div>
      </div>

      <div className="mt-3">
        <p className="text-xs font-medium text-slate-500">탐지 내역</p>
        <pre className="mt-1 whitespace-pre-wrap rounded-lg bg-slate-100 p-2 text-xs text-slate-700">
          {diagnosis.detectedIssue}
        </pre>
      </div>

      {diagnosis.diagnosisText && (
        <div className="mt-3">
          <p className="text-xs font-medium text-slate-500">AI 진단 — 원인 분석</p>
          <p className="mt-1 whitespace-pre-wrap text-sm text-slate-800">{diagnosis.diagnosisText}</p>
        </div>
      )}
      {diagnosis.suggestedAction && (
        <div className="mt-2">
          <p className="text-xs font-medium text-slate-500">AI 진단 — 권장 조치(운영자가 직접 수행)</p>
          <p className="mt-1 whitespace-pre-wrap text-sm text-indigo-800">{diagnosis.suggestedAction}</p>
        </div>
      )}

      {diagnosis.status === "approved" && (
        <p className="mt-3 text-xs text-emerald-700">
          {diagnosis.approvedAdminName ?? "운영자"}님이 승인했습니다. SSH로 직접 조치를 수행해주세요(자동 실행 없음).
        </p>
      )}

      <div className="mt-3 flex flex-wrap gap-2">
        {diagnosis.status === "detected" && canDiagnose && (
          <form action={diagnoseAction}>
            <input type="hidden" name="id" value={diagnosis.id} />
            <button
              type="submit"
              disabled={diagnosePending}
              className="rounded-lg border border-indigo-300 px-3 py-1.5 text-xs font-medium text-indigo-700 hover:bg-indigo-100 disabled:opacity-50"
            >
              {diagnosePending ? "진단 중..." : "② AI 진단 실행"}
            </button>
          </form>
        )}
        {diagnosis.status === "diagnosed" && canApprove && (
          <>
            <form action={approveFormAction}>
              <input type="hidden" name="id" value={diagnosis.id} />
              <button
                type="submit"
                disabled={approvePending}
                className="rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-500 disabled:opacity-50"
              >
                {approvePending ? "처리 중..." : "③ 승인(조치 수행 예정)"}
              </button>
            </form>
            <form action={rejectFormAction}>
              <input type="hidden" name="id" value={diagnosis.id} />
              <button
                type="submit"
                disabled={rejectPending}
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
              >
                {rejectPending ? "처리 중..." : "반려"}
              </button>
            </form>
          </>
        )}
      </div>
      {diagnoseState.error && <p className="mt-2 text-xs text-red-700">{diagnoseState.error}</p>}
      {approveState.error && <p className="mt-2 text-xs text-red-700">{approveState.error}</p>}
      {rejectState.error && <p className="mt-2 text-xs text-red-700">{rejectState.error}</p>}
    </div>
  );
}
