"use client";

import { useActionState, useRef } from "react";
import { createRankingReward, type RankingRewardFormState } from "@/app/actions/ranking-rewards";

const initialState: RankingRewardFormState = {};

export default function RankingRewardCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createRankingReward, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-5"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">새 랭킹 보상 구간 추가</h3>
      <input
        type="text"
        name="rankingType"
        placeholder="ranking_type (예: point)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="rankRangeMin"
        placeholder="시작 순위"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="rankRangeMax"
        placeholder="종료 순위"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="rewardPoint"
        placeholder="보상 포인트"
        required
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="rewardItemType"
        placeholder="보상 아이템 유형(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          랭킹 보상 구간이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "보상 구간 추가"}
        </button>
      </div>
    </form>
  );
}
