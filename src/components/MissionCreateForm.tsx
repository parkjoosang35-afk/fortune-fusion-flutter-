"use client";

import { useActionState, useRef } from "react";
import { createMission, type MissionFormState } from "@/app/actions/missions";

const initialState: MissionFormState = {};

export default function MissionCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createMission, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">새 미션 추가</h3>
      <input
        type="text"
        name="title"
        placeholder="미션 제목"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="actionType"
        placeholder="action_type (예: daily_login)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <select
        name="periodType"
        defaultValue="daily"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      >
        <option value="daily">일간(daily)</option>
        <option value="weekly">주간(weekly)</option>
        <option value="achievement">업적형(achievement)</option>
      </select>
      <input
        type="number"
        name="targetCount"
        placeholder="목표 횟수"
        required
        min={1}
        defaultValue={1}
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
      <input
        type="number"
        name="rewardItemId"
        placeholder="보상 아이템 ID(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        시작일시(선택)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        종료일시(선택)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          미션이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "미션 추가"}
        </button>
      </div>
    </form>
  );
}
