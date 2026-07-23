"use client";

import { useActionState } from "react";
import { requestRefund, type RefundFormState } from "@/app/actions/payment-refunds";

interface RefundRequestFormProps {
  eligiblePayments: {
    id: number;
    pgTxId: string;
    userNickname: string;
    amount: number;
  }[];
}

const initialState: RefundFormState = {};

export default function RefundRequestForm({ eligiblePayments }: RefundRequestFormProps) {
  const [state, formAction, pending] = useActionState(requestRefund, initialState);

  if (eligiblePayments.length === 0) {
    return (
      <p className="mb-6 rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-500">
        환불 요청이 가능한 결제 내역(paid 상태, 대기중인 환불요청 없음)이 없습니다.
      </p>
    );
  }

  return (
    <form action={formAction} className="mb-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
      <p className="mb-3 text-sm font-semibold text-white">새 환불 요청 생성</p>
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-xs text-slate-500">결제 내역</label>
          <select
            name="paymentId"
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            required
          >
            {eligiblePayments.map((p) => (
              <option key={p.id} value={p.id}>
                {p.pgTxId} / {p.userNickname} / {p.amount.toLocaleString()}원
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-xs text-slate-500">환불 금액</label>
          <input
            type="number"
            name="amount"
            min={1}
            required
            className="w-32 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            placeholder="금액"
          />
        </div>
        <div className="flex-1">
          <label className="mb-1 block text-xs text-slate-500">환불 사유(필수)</label>
          <input
            type="text"
            name="reason"
            required
            className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white"
            placeholder="환불 사유를 입력하세요"
          />
        </div>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          환불 요청
        </button>
      </div>
      {state.error && <p className="mt-2 text-xs text-red-400">{state.error}</p>}
      {state.success && <p className="mt-2 text-xs text-emerald-400">환불 요청이 생성되었습니다(승인 대기).</p>}
    </form>
  );
}
