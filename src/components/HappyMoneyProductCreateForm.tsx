"use client";

import { useActionState, useRef } from "react";
import { createHappyMoneyProduct, type HappyMoneyProductFormState } from "@/app/actions/happy-money-products";

const initialState: HappyMoneyProductFormState = {};

export default function HappyMoneyProductCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createHappyMoneyProduct, initialState);
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
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 행복머니 충전 상품 추가</h2>
      <input
        type="text"
        name="name"
        placeholder="상품명 (예: 행복머니 10,000원 충전)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="number"
        name="cashPrice"
        placeholder="현금 가격(원)"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="happyMoneyAmount"
        placeholder="지급 행복머니 수량"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="bonusAmount"
        placeholder="보너스 수량(선택)"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="displayPriority"
        placeholder="정렬 우선순위"
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="allowedUsageScopes"
        placeholder="사용 가능 상품군(콤마구분: pass,subscription,gift)"
        defaultValue="pass,subscription,gift"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <div className="flex flex-wrap items-center gap-3 md:col-span-2">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isFeatured" className="accent-indigo-500" /> 추천
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isEventGrantable" defaultChecked className="accent-indigo-500" /> 이벤트 지급 가능
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
          상품이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "상품 추가"}
        </button>
      </div>
    </form>
  );
}
