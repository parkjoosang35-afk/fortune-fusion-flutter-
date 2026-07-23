"use client";

import { useActionState, useState } from "react";
import {
  updatePointPolicy,
  deletePointPolicy,
  type PointPolicyFormState,
} from "@/app/actions/point-policies";

interface PointPolicyRowProps {
  policy: {
    id: number;
    sourceType: string;
    amount: number;
    dailyLimit: number | null;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const EARN_SOURCE_TYPES = ["attendance", "mission", "event", "community", "purchase", "admin_adjust", "refund"];

function policyKind(sourceType: string): "earn" | "spend" {
  return EARN_SOURCE_TYPES.some((s) => sourceType.startsWith(s)) ? "earn" : "spend";
}

const initialState: PointPolicyFormState = {};

export default function PointPolicyRow({ policy, canWrite, canDelete }: PointPolicyRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updatePointPolicy, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deletePointPolicy, initialState);

  const kind = policyKind(policy.sourceType);
  const kindBadge =
    kind === "earn" ? (
      <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">적립형</span>
    ) : (
      <span className="rounded-full bg-amber-950/60 px-2 py-0.5 text-xs text-amber-400">
        차감형(무료/유료)
      </span>
    );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={policy.id} />
            <input
              type="text"
              name="sourceType"
              defaultValue={policy.sourceType}
              className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="amount"
              defaultValue={policy.amount}
              min={0}
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="dailyLimit"
              defaultValue={policy.dailyLimit ?? ""}
              min={0}
              placeholder="한도(선택)"
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input type="checkbox" name="isActive" defaultChecked={policy.isActive} className="accent-indigo-500" />
              활성
            </label>
            <button
              type="submit"
              disabled={updatePending}
              className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              저장
            </button>
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
            >
              취소
            </button>
            {updateState.error && (
              <p className="w-full text-xs text-red-400">{updateState.error}</p>
            )}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 font-mono text-slate-200">{policy.sourceType}</td>
      <td className="px-4 py-3">{kindBadge}</td>
      <td className="px-4 py-3 text-slate-300">{policy.amount.toLocaleString()}P</td>
      <td className="px-4 py-3 text-slate-400">
        {policy.dailyLimit != null ? policy.dailyLimit.toLocaleString() : "무제한"}
      </td>
      <td className="px-4 py-3">
        {policy.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">활성</span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">비활성</span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
            >
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={policy.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
