"use client";

import { useActionState, useState } from "react";
import {
  updateAchievement,
  deleteAchievement,
  type AchievementFormState,
} from "@/app/actions/achievements";

interface AchievementRowProps {
  achievement: {
    id: number;
    code: string;
    title: string;
    conditionType: string;
    conditionValue: string;
    rewardPoint: number;
    badgeImageFileId: number | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: AchievementFormState = {};

export default function AchievementRow({ achievement, canWrite, canDelete }: AchievementRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateAchievement, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteAchievement, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={achievement.id} />
            <input
              type="text"
              name="code"
              defaultValue={achievement.code}
              className="w-32 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="title"
              defaultValue={achievement.title}
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="conditionType"
              defaultValue={achievement.conditionType}
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="conditionValue"
              defaultValue={achievement.conditionValue}
              className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rewardPoint"
              defaultValue={achievement.rewardPoint}
              min={0}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="badgeImageFileId"
              defaultValue={achievement.badgeImageFileId ?? ""}
              placeholder="배지ID"
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
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
      <td className="px-4 py-3 font-mono text-slate-200">{achievement.code}</td>
      <td className="px-4 py-3 text-slate-300">{achievement.title}</td>
      <td className="px-4 py-3 text-slate-400">{achievement.conditionType}</td>
      <td className="px-4 py-3 text-slate-500">{achievement.conditionValue}</td>
      <td className="px-4 py-3 text-slate-300">{achievement.rewardPoint.toLocaleString()}P</td>
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
              <input type="hidden" name="id" value={achievement.id} />
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
