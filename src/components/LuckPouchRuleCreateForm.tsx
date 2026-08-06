"use client";

import { useActionState, useRef } from "react";
import { createLuckPouchRule, type LuckPouchRuleFormState } from "@/app/actions/luck-pouch-rules";

const initialState: LuckPouchRuleFormState = {};

const RULE_TYPE_OPTIONS = [
  { value: "earn", label: "적립(earn)" },
  { value: "spend", label: "소비(spend)" },
  { value: "purchase", label: "구매(purchase)" },
];

export default function LuckPouchRuleCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createLuckPouchRule, initialState);
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
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 복주머니 규칙 추가</h2>
      <input
        type="text"
        name="name"
        placeholder="규칙명 (예: 응원(cheer) 사용)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="ruleType"
        defaultValue="earn"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
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
        placeholder="actionType(예: cheer/highlight/attendance)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="targetScope"
        placeholder="적용 scope(선택, 예: wish_board)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="amount"
        placeholder="수량(적립/소비/구매 지급량)"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="cashPrice"
        placeholder="현금 가격(구매 규칙만, 선택)"
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="dailyLimit"
        placeholder="1일 한도(선택, 무제한=공란)"
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="displayPriority"
        placeholder="정렬 우선순위"
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <div className="flex flex-wrap items-center gap-3 md:col-span-2">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isPurchasable" className="accent-indigo-500" /> 구매 가능(노출)
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isManualGrantable" defaultChecked className="accent-indigo-500" /> 수동 지급 가능
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" /> 활성화
        </label>
      </div>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          규칙이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "규칙 추가"}
        </button>
      </div>
    </form>
  );
}
