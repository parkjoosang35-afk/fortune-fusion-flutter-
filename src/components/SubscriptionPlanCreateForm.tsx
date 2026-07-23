"use client";

import { useActionState, useRef } from "react";
import { createSubscriptionPlan, type PlanFormState } from "@/app/actions/subscription-plans";

interface SubscriptionPlanCreateFormProps {
  canWrite: boolean;
}

const initialState: PlanFormState = {};

export default function SubscriptionPlanCreateForm({ canWrite }: SubscriptionPlanCreateFormProps) {
  const [state, formAction, pending] = useActionState(createSubscriptionPlan, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 구독 플랜 추가</h3>
      <input
        type="text"
        name="name"
        placeholder="플랜명"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="number"
        name="price"
        placeholder="가격(원)"
        min={0}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <select
        name="period"
        required
        defaultValue="monthly"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="monthly">월간(monthly)</option>
        <option value="yearly">연간(yearly)</option>
      </select>
      <textarea
        name="benefitsText"
        placeholder="혜택(줄바꿈으로 구분하여 여러 개 입력)"
        required
        rows={3}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-3"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">{state.error}</p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          구독 플랜이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "플랜 추가"}
        </button>
      </div>
    </form>
  );
}
