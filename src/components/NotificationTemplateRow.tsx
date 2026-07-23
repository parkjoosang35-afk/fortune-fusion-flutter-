"use client";

import { useActionState, useState } from "react";
import {
  updateNotificationTemplate,
  deleteNotificationTemplate,
  type NotificationTemplateFormState,
} from "@/app/actions/notification-templates";

interface NotificationTemplateRowProps {
  template: {
    id: number;
    code: string;
    title: string;
    body: string;
    deepLink: string | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: NotificationTemplateFormState = {};

export default function NotificationTemplateRow({
  template,
  canWrite,
  canDelete,
}: NotificationTemplateRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateNotificationTemplate,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteNotificationTemplate,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-col gap-2">
            <input type="hidden" name="id" value={template.id} />
            <div className="flex flex-wrap gap-2">
              <input
                type="text"
                name="code"
                defaultValue={template.code}
                className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              />
              <input
                type="text"
                name="deepLink"
                defaultValue={template.deepLink ?? ""}
                placeholder="딥링크 URL (선택)"
                className="flex-1 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              />
            </div>
            <input
              type="text"
              name="title"
              defaultValue={template.title}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <textarea
              name="body"
              defaultValue={template.body}
              rows={3}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <div className="flex items-center gap-2">
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
            </div>
            {updateState.error && <p className="text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3">
        <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs font-mono text-slate-300">
          {template.code}
        </span>
      </td>
      <td className="px-4 py-3">
        <div className="font-medium text-slate-200">{template.title}</div>
        <p className="mt-1 max-w-xl truncate text-xs text-slate-500">{template.body}</p>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {template.deepLink ?? <span className="text-slate-600">-</span>}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
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
              <input type="hidden" name="id" value={template.id} />
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
