"use client";

import { useActionState, useState } from "react";
import { updateAmuletGrade, type AmuletFormState } from "@/app/actions/amulets";

interface AmuletGradeRowProps {
  grade: {
    id: number;
    code: string;
    name: string;
    sortOrder: number;
  };
  itemCount: number;
  canWrite: boolean;
}

const initialState: AmuletFormState = {};

export default function AmuletGradeRow({ grade, itemCount, canWrite }: AmuletGradeRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateAmuletGrade, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={grade.id} />
            <input
              type="text"
              name="code"
              defaultValue={grade.code}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="name"
              defaultValue={grade.name}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="sortOrder"
              defaultValue={grade.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
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
      <td className="px-4 py-3 font-mono text-slate-700">{grade.code}</td>
      <td className="px-4 py-3 text-slate-600">{grade.name}</td>
      <td className="px-4 py-3 text-slate-500">{itemCount.toLocaleString()}종</td>
      <td className="px-4 py-3">
        {canWrite && (
          <button
            onClick={() => setEditing(true)}
            className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100"
          >
            수정
          </button>
        )}
      </td>
    </tr>
  );
}
