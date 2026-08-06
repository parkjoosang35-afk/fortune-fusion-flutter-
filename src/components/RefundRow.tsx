"use client";

import { useActionState } from "react";
import { approveRefund, rejectRefund, type RefundFormState } from "@/app/actions/payment-refunds";

interface RefundRowProps {
  refund: {
    id: number;
    paymentId: number;
    pgTxId: string;
    userNickname: string;
    amount: number;
    reason: string | null;
    status: string; // pending/completed/failed
    processedAt: Date | null;
    createdAt: Date;
  };
  canApprove: boolean; // super_admin 전용
}

const initialState: RefundFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  pending: { label: "승인대기", cls: "bg-amber-100 text-amber-700" },
  completed: { label: "환불완료", cls: "bg-emerald-100 text-emerald-700" },
  failed: { label: "거부됨", cls: "bg-rose-100 text-rose-700" },
};

function fmtDate(d: Date | null): string {
  if (!d) return "-";
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function RefundRow({ refund, canApprove }: RefundRowProps) {
  const [approveState, approveAction, approvePending] = useActionState(approveRefund, initialState);
  const [rejectState, rejectAction, rejectPending] = useActionState(rejectRefund, initialState);

  const st = STATUS_LABEL[refund.status] ?? { label: refund.status, cls: "bg-white text-slate-500" };

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40 align-top">
      <td className="px-4 py-3 text-slate-500 font-mono text-xs">{refund.pgTxId}</td>
      <td className="px-4 py-3 text-slate-700">{refund.userNickname}</td>
      <td className="px-4 py-3 text-slate-700">{refund.amount.toLocaleString()}원</td>
      <td className="px-4 py-3 text-slate-500">{refund.reason ?? "-"}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(refund.createdAt)}</td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(refund.processedAt)}</td>
      <td className="px-4 py-3">
        {refund.status === "pending" ? (
          canApprove ? (
            <div className="flex flex-wrap gap-2">
              <form action={approveAction}>
                <input type="hidden" name="id" value={refund.id} />
                <button
                  type="submit"
                  disabled={approvePending}
                  className="rounded-lg border border-emerald-300 px-3 py-1 text-xs text-emerald-700 hover:bg-emerald-100 disabled:opacity-50"
                >
                  승인(환불완료)
                </button>
              </form>
              <form action={rejectAction}>
                <input type="hidden" name="id" value={refund.id} />
                <button
                  type="submit"
                  disabled={rejectPending}
                  className="rounded-lg border border-rose-300 px-3 py-1 text-xs text-rose-700 hover:bg-rose-100 disabled:opacity-50"
                >
                  거부
                </button>
              </form>
            </div>
          ) : (
            <span className="text-xs text-slate-600">최종승인은 super_admin만 가능</span>
          )
        ) : (
          <span className="text-xs text-slate-600">처리 완료</span>
        )}
        {approveState.error && <p className="mt-1 text-xs text-red-700">{approveState.error}</p>}
        {rejectState.error && <p className="mt-1 text-xs text-red-700">{rejectState.error}</p>}
      </td>
    </tr>
  );
}
