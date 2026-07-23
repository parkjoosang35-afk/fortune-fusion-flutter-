"use client";

import { useActionState, useRef } from "react";
import { createCoupon, type CouponFormState } from "@/app/actions/coupons";

interface CouponCreateFormProps {
  canWrite: boolean;
}

const initialState: CouponFormState = {};

export default function CouponCreateForm({ canWrite }: CouponCreateFormProps) {
  const [state, formAction, pending] = useActionState(createCoupon, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  const today = new Date().toISOString().slice(0, 10);

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 쿠폰 추가</h3>
      <input
        type="text"
        name="code"
        placeholder="쿠폰 코드 (예: WELCOME2026)"
        required
        maxLength={30}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="discountType"
        required
        defaultValue="rate"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="rate">할인율(%)</option>
        <option value="fixed_point">고정 포인트</option>
      </select>
      <input
        type="number"
        name="discountValue"
        placeholder="할인 값"
        min={0}
        step="0.01"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        유효 시작일
        <input
          type="date"
          name="validFrom"
          required
          defaultValue={today}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        유효 종료일
        <input
          type="date"
          name="validTo"
          required
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <input
        type="number"
        name="usageLimit"
        placeholder="발급 한도 (비우면 무제한)"
        min={1}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          쿠폰이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "쿠폰 추가"}
        </button>
      </div>
    </form>
  );
}
