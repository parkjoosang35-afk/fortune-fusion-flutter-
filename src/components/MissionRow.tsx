"use client";

import { useActionState, useState } from "react";
import { updateMission, deleteMission, type MissionFormState } from "@/app/actions/missions";

interface MissionRowProps {
  mission: {
    id: number;
    title: string;
    actionType: string;
    targetCount: number;
    rewardPoint: number;
    rewardItemType: string | null;
    rewardItemId: number | null;
    periodType: string;
    startAt: Date | null;
    endAt: Date | null;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: MissionFormState = {};

const PERIOD_LABEL: Record<string, string> = {
  daily: "일간",
  weekly: "주간",
  achievement: "업적형",
};

function toLocalInputValue(d: Date | null): string {
  if (!d) return "";
  return d.toISOString().slice(0, 16);
}

export default function MissionRow({ mission, canWrite, canDelete }: MissionRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateMission, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteMission, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={mission.id} />
            <input
              type="text"
              name="title"
              defaultValue={mission.title}
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="actionType"
              defaultValue={mission.actionType}
              className="w-32 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="periodType"
              defaultValue={mission.periodType}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              <option value="daily">일간</option>
              <option value="weekly">주간</option>
              <option value="achievement">업적형</option>
            </select>
            <input
              type="number"
              name="targetCount"
              defaultValue={mission.targetCount}
              min={1}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rewardPoint"
              defaultValue={mission.rewardPoint}
              min={0}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="rewardItemType"
              defaultValue={mission.rewardItemType ?? ""}
              placeholder="보상유형"
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rewardItemId"
              defaultValue={mission.rewardItemId ?? ""}
              placeholder="보상ID"
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(mission.startAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(mission.endAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={mission.isActive} className="accent-indigo-500" />
              활성
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
            {updateState.error && <p className="w-full text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-700">{mission.title}</td>
      <td className="px-4 py-3 font-mono text-slate-500">{mission.actionType}</td>
      <td className="px-4 py-3 text-slate-600">{PERIOD_LABEL[mission.periodType] ?? mission.periodType}</td>
      <td className="px-4 py-3 text-slate-500">{mission.targetCount.toLocaleString()}회</td>
      <td className="px-4 py-3 text-slate-600">{mission.rewardPoint.toLocaleString()}P</td>
      <td className="px-4 py-3">
        {mission.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
        )}
      </td>
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
              <input type="hidden" name="id" value={mission.id} />
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
