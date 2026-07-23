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
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={grade.id} />
            <input
              type="text"
              name="code"
              defaultValue={grade.code}
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="name"
              defaultValue={grade.name}
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="sortOrder"
              defaultValue={grade.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
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
              className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
            >
              취소
            </button>
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 font-mono text-slate-200">{grade.code}</td>
      <td className="px-4 py-3 text-slate-300">{grade.name}</td>
      <td className="px-4 py-3 text-slate-400">{itemCount.toLocaleString()}종</td>
      <td className="px-4 py-3">
        {canWrite && (
          <button
            onClick={() => setEditing(true)}
            className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
          >
            수정
          </button>
        )}
      </td>
    </tr>
  );
}
