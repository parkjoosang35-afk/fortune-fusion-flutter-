"use client";

import { useActionState, useState } from "react";
import {
  updateAttendanceRule,
  deleteAttendanceRule,
  type AttendanceRuleFormState,
} from "@/app/actions/attendance-rules";

interface AttendanceRuleRowProps {
  rule: {
    id: number;
    streakDay: number;
    rewardPoint: number;
    bonusItemType: string | null;
    bonusItemId: number | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: AttendanceRuleFormState = {};

export default function AttendanceRuleRow({ rule, canWrite, canDelete }: AttendanceRuleRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateAttendanceRule, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteAttendanceRule, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={rule.id} />
            <input
              type="number"
              name="streakDay"
              defaultValue={rule.streakDay}
              min={1}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rewardPoint"
              defaultValue={rule.rewardPoint}
              min={0}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="bonusItemType"
              defaultValue={rule.bonusItemType ?? ""}
              placeholder="보너스유형"
              className="w-32 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="bonusItemId"
              defaultValue={rule.bonusItemId ?? ""}
              placeholder="보너스ID"
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
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
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100"
            >
              취소
            </button>
            {updateState.error && <p className="w-full text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-700">{rule.streakDay}일</td>
      <td className="px-4 py-3 text-slate-600">{rule.rewardPoint.toLocaleString()}P</td>
      <td className="px-4 py-3 text-slate-500">{rule.bonusItemType ?? "-"}</td>
      <td className="px-4 py-3 text-slate-500">{rule.bonusItemId ?? "-"}</td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100"
            >
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={rule.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-300 px-3 py-1 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
