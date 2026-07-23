"use client";

import { useActionState, useState } from "react";
import { updateAdminPermission, type PermissionFormState } from "@/app/actions/admin-permissions";

const initialState: PermissionFormState = {};

interface PermissionMatrixCellProps {
  roleId: number;
  menuCode: string;
  canRead: boolean;
  canWrite: boolean;
  canDelete: boolean;
  editable: boolean;
}

export default function PermissionMatrixCell({
  roleId,
  menuCode,
  canRead,
  canWrite,
  canDelete,
  editable,
}: PermissionMatrixCellProps) {
  const [state, formAction, pending] = useActionState(updateAdminPermission, initialState);
  const [editing, setEditing] = useState(false);
  const [read, setRead] = useState(canRead);
  const [write, setWrite] = useState(canWrite);
  const [del, setDel] = useState(canDelete);

  if (!editable) {
    return (
      <td className="px-3 py-2 text-center text-xs text-slate-400">
        {canRead ? "R" : "-"}
        {canWrite ? "W" : "-"}
        {canDelete ? "D" : "-"}
      </td>
    );
  }

  if (!editing) {
    return (
      <td className="px-3 py-2 text-center">
        <button
          onClick={() => setEditing(true)}
          className="rounded px-2 py-1 text-xs font-mono text-slate-300 hover:bg-slate-800"
          title="클릭하여 편집"
        >
          {canRead ? "R" : "-"}
          {canWrite ? "W" : "-"}
          {canDelete ? "D" : "-"}
        </button>
      </td>
    );
  }

  return (
    <td className="px-2 py-2">
      <form
        action={async (fd) => {
          await formAction(fd);
          setEditing(false);
        }}
        className="flex flex-col items-center gap-1 rounded-lg border border-slate-700 bg-slate-800 p-2"
      >
        <input type="hidden" name="roleId" value={roleId} />
        <input type="hidden" name="menuCode" value={menuCode} />
        <div className="flex gap-2 text-xs text-slate-300">
          <label className="flex items-center gap-1">
            <input
              type="checkbox"
              name="canRead"
              checked={read}
              onChange={(e) => setRead(e.target.checked)}
              className="accent-indigo-500"
            />
            R
          </label>
          <label className="flex items-center gap-1">
            <input
              type="checkbox"
              name="canWrite"
              checked={write}
              onChange={(e) => setWrite(e.target.checked)}
              className="accent-indigo-500"
            />
            W
          </label>
          <label className="flex items-center gap-1">
            <input
              type="checkbox"
              name="canDelete"
              checked={del}
              onChange={(e) => setDel(e.target.checked)}
              className="accent-indigo-500"
            />
            D
          </label>
        </div>
        <div className="flex gap-1">
          <button
            type="submit"
            disabled={pending}
            className="rounded bg-indigo-600 px-2 py-0.5 text-xs text-white hover:bg-indigo-500"
          >
            저장
          </button>
          <button
            type="button"
            onClick={() => setEditing(false)}
            className="rounded bg-slate-700 px-2 py-0.5 text-xs text-slate-300 hover:bg-slate-600"
          >
            취소
          </button>
        </div>
        {state.error && <p className="text-[10px] text-red-400">{state.error}</p>}
      </form>
    </td>
  );
}
