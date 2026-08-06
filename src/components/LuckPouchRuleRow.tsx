"use client";

import { useActionState, useState } from "react";
import { updateLuckPouchRule, deleteLuckPouchRule, type LuckPouchRuleFormState } from "@/app/actions/luck-pouch-rules";

interface LuckPouchRuleRowProps {
  rule: {
    id: number;
    name: string;
    ruleType: string;
    actionType: string;
    targetScope: string | null;
    amount: number;
    cashPrice: number | null;
    dailyLimit: number | null;
    isPurchasable: boolean;
    isManualGrantable: boolean;
    displayPriority: number;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const RULE_TYPE_BADGE: Record<string, string> = {
  earn: "bg-emerald-100 text-emerald-700",
  spend: "bg-sky-100 text-sky-700",
  purchase: "bg-amber-100 text-amber-700",
};

const RULE_TYPE_OPTIONS = [
  { value: "earn", label: "적립" },
  { value: "spend", label: "소비" },
  { value: "purchase", label: "구매" },
];

const initialState: LuckPouchRuleFormState = {};

export default function LuckPouchRuleRow({ rule, canWrite, canDelete }: LuckPouchRuleRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateLuckPouchRule, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteLuckPouchRule, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={8} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={rule.id} />
            <input
              type="text"
              name="name"
              defaultValue={rule.name}
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="ruleType"
              defaultValue={rule.ruleType}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {RULE_TYPE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
            <input
              type="text"
              name="actionType"
              defaultValue={rule.actionType}
              className="w-32 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="targetScope"
              defaultValue={rule.targetScope ?? ""}
              placeholder="scope"
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="amount"
              defaultValue={rule.amount}
              min={1}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="cashPrice"
              defaultValue={rule.cashPrice ?? ""}
              placeholder="원가"
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="dailyLimit"
              defaultValue={rule.dailyLimit ?? ""}
              placeholder="한도"
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isPurchasable" defaultChecked={rule.isPurchasable} className="accent-indigo-500" /> 구매노출
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isManualGrantable" defaultChecked={rule.isManualGrantable} className="accent-indigo-500" /> 수동지급
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={rule.isActive} className="accent-indigo-500" /> 활성
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
      <td className="px-4 py-3 text-slate-700">{rule.name}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${RULE_TYPE_BADGE[rule.ruleType] ?? "bg-white text-slate-500"}`}>
          {RULE_TYPE_OPTIONS.find((o) => o.value === rule.ruleType)?.label ?? rule.ruleType}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-600">{rule.actionType}</td>
      <td className="px-4 py-3 text-slate-500">{rule.targetScope ?? "-"}</td>
      <td className="px-4 py-3 text-slate-600">
        {rule.ruleType === "spend" ? "-" : "+"}
        {rule.amount.toLocaleString()}
        {rule.cashPrice != null && <span className="text-slate-500"> ({rule.cashPrice.toLocaleString()}원)</span>}
      </td>
      <td className="px-4 py-3 text-slate-500">{rule.dailyLimit != null ? rule.dailyLimit.toLocaleString() : "무제한"}</td>
      <td className="px-4 py-3">
        {rule.isActive ? (
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
              <input type="hidden" name="id" value={rule.id} />
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
