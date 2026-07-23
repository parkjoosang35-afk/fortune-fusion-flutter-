"use client";

import { useActionState, useState } from "react";
import { updateBoard, deleteBoard, type CommunityFormState } from "@/app/actions/community";

interface CommunityBoardRowProps {
  board: {
    id: number;
    code: string;
    name: string;
    description: string | null;
    sortOrder: number;
    isPublic: boolean;
    postCount: number;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: CommunityFormState = {};

export default function CommunityBoardRow({ board, canWrite, canDelete }: CommunityBoardRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateBoard, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteBoard, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={board.id} />
            <span className="rounded-lg border border-slate-700 bg-slate-900 px-2 py-1 text-xs text-slate-400">
              {board.code} (코드 수정 불가)
            </span>
            <input
              type="text"
              name="name"
              defaultValue={board.name}
              required
              maxLength={50}
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="description"
              defaultValue={board.description ?? ""}
              maxLength={200}
              placeholder="설명"
              className="w-56 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="sortOrder"
              defaultValue={board.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input type="checkbox" name="isPublic" defaultChecked={board.isPublic} className="h-4 w-4" />
              공개
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
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 font-mono text-slate-200">{board.code}</td>
      <td className="px-4 py-3 text-slate-300">{board.name}</td>
      <td className="px-4 py-3 text-slate-400">{board.description ?? "-"}</td>
      <td className="px-4 py-3 text-slate-400">{board.postCount.toLocaleString()}</td>
      <td className="px-4 py-3">
        {board.isPublic ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">공개</span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-500">비공개</span>
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
              <input type="hidden" name="id" value={board.id} />
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
