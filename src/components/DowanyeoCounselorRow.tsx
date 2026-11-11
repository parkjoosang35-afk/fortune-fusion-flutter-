"use client";

import { useActionState } from "react";
import { updateCounselorStatus, type DowanyeoFormState } from "@/app/actions/dowanyeo";

const initialState: DowanyeoFormState = {};

interface DowanyeoCounselorRowProps {
  counselor: {
    id: number;
    name: string;
    specialty: string | null;
    status: string;
  };
  canWrite: boolean;
}

export default function DowanyeoCounselorRow({ counselor, canWrite }: DowanyeoCounselorRowProps) {
  const [state, formAction, pending] = useActionState(updateCounselorStatus, initialState);
  const nextStatus = counselor.status === "active" ? "inactive" : "active";

  return (
    <div className="flex items-center justify-between rounded-lg border border-slate-200 bg-white/40 px-3 py-2">
      <div>
        <span className="text-sm font-medium text-slate-900">{counselor.name}</span>
        {counselor.specialty && (
          <span className="ml-2 text-xs text-slate-500">{counselor.specialty}</span>
        )}
        <span
          className={`ml-2 rounded-full px-2 py-0.5 text-[10px] ${
            counselor.status === "active"
              ? "bg-emerald-100 text-emerald-700"
              : "bg-slate-100 text-slate-500"
          }`}
        >
          {counselor.status === "active" ? "활성" : "비활성"}
        </span>
      </div>
      {canWrite && (
        <form action={formAction}>
          <input type="hidden" name="id" value={counselor.id} />
          <input type="hidden" name="status" value={nextStatus} />
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg border border-slate-300 px-2.5 py-1 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
          >
            {pending ? "처리 중..." : nextStatus === "inactive" ? "비활성화" : "활성화"}
          </button>
        </form>
      )}
      {state.error && <p className="text-xs text-red-700">{state.error}</p>}
    </div>
  );
}
