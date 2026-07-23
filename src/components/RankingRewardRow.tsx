"use client";

import { useActionState, useState } from "react";
import {
  updateRankingReward,
  deleteRankingReward,
  type RankingRewardFormState,
} from "@/app/actions/ranking-rewards";

interface RankingRewardRowProps {
  reward: {
    id: number;
    rankingType: string;
    rankRangeMin: number;
    rankRangeMax: number;
    rewardPoint: number;
    rewardItemType: string | null;
    rewardItemId: number | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: RankingRewardFormState = {};

export default function RankingRewardRow({ reward, canWrite, canDelete }: RankingRewardRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateRankingReward, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteRankingReward, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={reward.id} />
            <input
              type="text"
              name="rankingType"
              defaultValue={reward.rankingType}
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rankRangeMin"
              defaultValue={reward.rankRangeMin}
              min={1}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rankRangeMax"
              defaultValue={reward.rankRangeMax}
              min={1}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="rewardPoint"
              defaultValue={reward.rewardPoint}
              min={0}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="rewardItemType"
              defaultValue={reward.rewardItemType ?? ""}
              placeholder="보상유형"
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
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
      <td className="px-4 py-3 font-mono text-slate-200">{reward.rankingType}</td>
      <td className="px-4 py-3 text-slate-300">
        {reward.rankRangeMin}위 ~ {reward.rankRangeMax}위
      </td>
      <td className="px-4 py-3 text-slate-300">{reward.rewardPoint.toLocaleString()}P</td>
      <td className="px-4 py-3 text-slate-400">{reward.rewardItemType ?? "-"}</td>
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
              <input type="hidden" name="id" value={reward.id} />
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
