"use client";

// [관리자 2.0 전면 재설계 - Task 12a] 도완녀상담 신청 — 상태별 액션 버튼.
// SystemDiagnosisRow.tsx의 useActionState 다중 훅 패턴 재사용.
import { useActionState, useState } from "react";
import {
  assignCounselor,
  startConsultation,
  completeConsultation,
  cancelRequest,
  type DowanyeoFormState,
} from "@/app/actions/dowanyeo";

const initialState: DowanyeoFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  requested: { label: "① 신청", cls: "bg-amber-100 text-amber-700" },
  assigned: { label: "② 배정완료", cls: "bg-indigo-100 text-indigo-700" },
  in_progress: { label: "③ 진행중", cls: "bg-blue-100 text-blue-700" },
  completed: { label: "④ 완료", cls: "bg-emerald-100 text-emerald-700" },
  cancelled: { label: "취소됨", cls: "bg-slate-100 text-slate-500" },
};

function fmtDate(d: Date | string | null): string {
  if (!d) return "-";
  return new Date(d).toISOString().slice(0, 19).replace("T", " ");
}

interface DowanyeoRequestRowProps {
  request: {
    id: number;
    topic: string;
    requestMemo: string | null;
    preferredAt: Date | string | null;
    status: string;
    createdAt: Date | string;
    userNickname: string;
    counselorName: string | null;
  };
  counselors: { id: number; name: string }[];
  canWrite: boolean;
  canCancel: boolean;
}

export default function DowanyeoRequestRow({
  request,
  counselors,
  canWrite,
  canCancel,
}: DowanyeoRequestRowProps) {
  const [assignState, assignAction, assignPending] = useActionState(assignCounselor, initialState);
  const [startState, startAction, startPending] = useActionState(startConsultation, initialState);
  const [completeState, completeAction, completePending] = useActionState(
    completeConsultation,
    initialState
  );
  const [cancelState, cancelAction, cancelPending] = useActionState(cancelRequest, initialState);
  const [selectedCounselorId, setSelectedCounselorId] = useState("");

  const st = STATUS_LABEL[request.status] ?? { label: request.status, cls: "bg-white text-slate-500" };

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${st.cls}`}>{st.label}</span>
          <span className="ml-2 text-sm font-medium text-slate-900">{request.topic}</span>
        </div>
        <span className="text-xs text-slate-500">{fmtDate(request.createdAt)}</span>
      </div>

      <div className="mt-2 text-xs text-slate-500">
        신청자: {request.userNickname} · 희망시각: {fmtDate(request.preferredAt)}
        {request.counselorName && <> · 배정 카운슬러: {request.counselorName}</>}
      </div>
      {request.requestMemo && (
        <p className="mt-1 whitespace-pre-wrap text-sm text-slate-700">{request.requestMemo}</p>
      )}

      {canWrite && (
        <div className="mt-3 flex flex-wrap items-center gap-2">
          {request.status === "requested" && (
            <form action={assignAction} className="flex items-center gap-2">
              <input type="hidden" name="id" value={request.id} />
              <select
                name="counselorId"
                value={selectedCounselorId}
                onChange={(e) => setSelectedCounselorId(e.target.value)}
                required
                className="rounded-lg border border-slate-300 bg-white px-2 py-1.5 text-xs text-slate-900 outline-none focus:border-indigo-500"
              >
                <option value="">카운슬러 선택</option>
                {counselors.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
              <button
                type="submit"
                disabled={assignPending}
                className="rounded-lg border border-indigo-300 px-3 py-1.5 text-xs font-medium text-indigo-700 hover:bg-indigo-100 disabled:opacity-50"
              >
                {assignPending ? "배정 중..." : "② 배정"}
              </button>
            </form>
          )}
          {request.status === "assigned" && (
            <form action={startAction}>
              <input type="hidden" name="id" value={request.id} />
              <button
                type="submit"
                disabled={startPending}
                className="rounded-lg border border-blue-300 px-3 py-1.5 text-xs font-medium text-blue-700 hover:bg-blue-100 disabled:opacity-50"
              >
                {startPending ? "처리 중..." : "③ 진행중으로 전환"}
              </button>
            </form>
          )}
          {request.status === "in_progress" && (
            <form action={completeAction}>
              <input type="hidden" name="id" value={request.id} />
              <button
                type="submit"
                disabled={completePending}
                className="rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-500 disabled:opacity-50"
              >
                {completePending ? "처리 중..." : "④ 완료 처리"}
              </button>
            </form>
          )}
          {canCancel && (request.status === "requested" || request.status === "assigned") && (
            <form action={cancelAction}>
              <input type="hidden" name="id" value={request.id} />
              <button
                type="submit"
                disabled={cancelPending}
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
              >
                {cancelPending ? "처리 중..." : "취소(환불)"}
              </button>
            </form>
          )}
        </div>
      )}
      {assignState.error && <p className="mt-2 text-xs text-red-700">{assignState.error}</p>}
      {startState.error && <p className="mt-2 text-xs text-red-700">{startState.error}</p>}
      {completeState.error && <p className="mt-2 text-xs text-red-700">{completeState.error}</p>}
      {cancelState.error && <p className="mt-2 text-xs text-red-700">{cancelState.error}</p>}
    </div>
  );
}
