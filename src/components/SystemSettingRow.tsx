"use client";

import { useActionState, useState } from "react";
import {
  updateSystemSetting,
  deleteSystemSetting,
  type SystemSettingFormState,
} from "@/app/actions/system-settings";

interface SystemSettingRowProps {
  setting: {
    id: number;
    key: string;
    value: string;
    description: string | null;
    updatedAt: Date;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: SystemSettingFormState = {};

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

// value는 JSON 문자열로 저장되어 있으므로(예: "false", "\"1.2.0\"", "{...}"),
// 편집 입력창에는 사람이 읽기 쉬운 원본 값을 보여준다(문자열이면 quote 제거).
function displayValue(jsonValue: string): string {
  try {
    const parsed = JSON.parse(jsonValue);
    if (typeof parsed === "string") return parsed;
    return JSON.stringify(parsed);
  } catch {
    return jsonValue;
  }
}

export default function SystemSettingRow({ setting, canWrite, canDelete }: SystemSettingRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateSystemSetting,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteSystemSetting,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={setting.id} />
            <span className="rounded-lg bg-slate-800 px-2 py-1.5 text-sm text-slate-400">
              {setting.key}
            </span>
            <input
              type="text"
              name="value"
              defaultValue={displayValue(setting.value)}
              className="min-w-[160px] rounded-lg border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="description"
              defaultValue={setting.description ?? ""}
              placeholder="설명"
              className="min-w-[200px] rounded-lg border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-white outline-none focus:border-indigo-500"
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
            {updateState.error && <p className="text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 font-mono text-xs text-slate-300">{setting.key}</td>
      <td className="px-4 py-3">
        <span className="rounded-full bg-indigo-950/60 px-2 py-0.5 text-xs text-indigo-300">
          {displayValue(setting.value)}
        </span>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">{setting.description ?? "-"}</td>
      <td className="px-4 py-3 text-xs text-slate-500">{formatDate(setting.updatedAt)}</td>
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
              <input type="hidden" name="id" value={setting.id} />
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
