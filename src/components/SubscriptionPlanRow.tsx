"use client";

import { useActionState, useState } from "react";
import {
  updateSubscriptionPlan,
  deleteSubscriptionPlan,
  type PlanFormState,
} from "@/app/actions/subscription-plans";

interface SubscriptionPlanRowProps {
  plan: {
    id: number;
    name: string;
    price: number;
    period: string; // monthly/yearly
    benefits: string[]; // 애플리케이션 레벨에서 JSON.parse된 배열
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: PlanFormState = {};

const PERIOD_LABEL: Record<string, string> = {
  monthly: "월간",
  yearly: "연간",
};

export default function SubscriptionPlanRow({ plan, canWrite, canDelete }: SubscriptionPlanRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateSubscriptionPlan, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteSubscriptionPlan, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-start gap-2">
            <input type="hidden" name="id" value={plan.id} />
            <input
              type="text"
              name="name"
              defaultValue={plan.name}
              className="w-36 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="price"
              defaultValue={plan.price}
              min={0}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="period"
              defaultValue={plan.period}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              <option value="monthly">월간</option>
              <option value="yearly">연간</option>
            </select>
            <textarea
              name="benefitsText"
              defaultValue={plan.benefits.join("\n")}
              rows={2}
              className="w-56 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={plan.isActive} className="accent-indigo-500" />
              활성화
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
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40 align-top">
      <td className="px-4 py-3 text-slate-700">{plan.name}</td>
      <td className="px-4 py-3 text-slate-600">{plan.price.toLocaleString()}원</td>
      <td className="px-4 py-3 text-slate-600">{PERIOD_LABEL[plan.period] ?? plan.period}</td>
      <td className="px-4 py-3 text-slate-500">
        <ul className="list-inside list-disc space-y-0.5">
          {plan.benefits.map((b, i) => (
            <li key={i}>{b}</li>
          ))}
        </ul>
      </td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            plan.isActive ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"
          }`}
        >
          {plan.isActive ? "활성" : "비활성"}
        </span>
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
              <input type="hidden" name="id" value={plan.id} />
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
