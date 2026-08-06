"use client";

import { useActionState, useState } from "react";
import {
  updateLuckybagSeason,
  deleteLuckybagSeason,
  type LuckybagFormState,
} from "@/app/actions/luckybag";

interface LuckybagSeasonRowProps {
  season: {
    id: number;
    name: string;
    startAt: Date;
    endAt: Date;
  };
  productCount: number;
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: LuckybagFormState = {};

function toLocalInputValue(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default function LuckybagSeasonRow({
  season,
  productCount,
  canWrite,
  canDelete,
}: LuckybagSeasonRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateLuckybagSeason, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteLuckybagSeason, initialState);

  const now = new Date();
  const isOngoing = season.startAt <= now && now <= season.endAt;

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={season.id} />
            <input
              type="text"
              name="name"
              defaultValue={season.name}
              className="w-56 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(season.startAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(season.endAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
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
      <td className="px-4 py-3 text-slate-700">
        {season.name}
        {isOngoing && (
          <span className="ml-2 rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
            진행중
          </span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-500">
        {season.startAt.toISOString().slice(0, 10)} ~ {season.endAt.toISOString().slice(0, 10)}
      </td>
      <td className="px-4 py-3 text-slate-500">{productCount.toLocaleString()}종</td>
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
              <input type="hidden" name="id" value={season.id} />
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
