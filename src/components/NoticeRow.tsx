"use client";

import { useActionState, useState } from "react";
import {
  updateNotice,
  deleteNotice,
  toggleNoticePinned,
  type NoticeFormState,
} from "@/app/actions/notices";

interface NoticeRowProps {
  notice: {
    id: number;
    title: string;
    content: string;
    isPinned: boolean;
    createdAt: Date;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: NoticeFormState = {};

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function NoticeRow({ notice, canWrite, canDelete }: NoticeRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateNotice, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteNotice, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleNoticePinned,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-col gap-2">
            <input type="hidden" name="id" value={notice.id} />
            <input
              type="text"
              name="title"
              defaultValue={notice.title}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <textarea
              name="content"
              defaultValue={notice.content}
              rows={3}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <div className="flex items-center gap-2">
              <label className="flex items-center gap-1 text-xs text-slate-600">
                <input
                  type="checkbox"
                  name="isPinned"
                  defaultChecked={notice.isPinned}
                  className="accent-indigo-500"
                />
                상단 고정
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
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100"
              >
                취소
              </button>
            </div>
            {updateState.error && <p className="text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3">
        <div className="font-medium text-slate-700">
          {notice.isPinned && (
            <span className="mr-1 rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-700">
              고정
            </span>
          )}
          {notice.title}
        </div>
        <p className="mt-1 max-w-xl truncate text-xs text-slate-500">{notice.content}</p>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">{formatDate(notice.createdAt)}</td>
      <td className="px-4 py-3">
        {notice.isPinned ? (
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
            고정됨
          </span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
            일반
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={notice.id} />
              <input type="hidden" name="isPinned" value={(!notice.isPinned).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
              >
                {notice.isPinned ? "고정 해제" : "고정하기"}
              </button>
            </form>
          )}
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
              <input type="hidden" name="id" value={notice.id} />
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
        {toggleState.error && <p className="mt-1 text-xs text-red-700">{toggleState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
