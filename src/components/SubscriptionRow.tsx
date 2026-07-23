"use client";

import { useActionState, useState } from "react";
import {
  forceCancelSubscription,
  type ForceCancelFormState,
} from "@/app/actions/user-subscriptions";

interface SubscriptionRowProps {
  subscription: {
    id: number;
    userNickname: string;
    planName: string;
    status: string; // active/cancelled/expired/past_due
    startedAt: Date;
    currentPeriodEnd: Date;
    pgSubscriptionId: string | null;
  };
  canForceCancel: boolean; // canWriteMenu(payments)
}

const initialState: ForceCancelFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  active: { label: "구독중", cls: "bg-emerald-950/60 text-emerald-400" },
  cancelled: { label: "해지됨", cls: "bg-slate-800 text-slate-400" },
  expired: { label: "만료됨", cls: "bg-slate-800 text-slate-500" },
  past_due: { label: "결제연체", cls: "bg-rose-950/60 text-rose-400" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function SubscriptionRow({ subscription, canForceCancel }: SubscriptionRowProps) {
  const [state, formAction, pending] = useActionState(forceCancelSubscription, initialState);
  const [showCancelForm, setShowCancelForm] = useState(false);

  const st = STATUS_LABEL[subscription.status] ?? {
    label: subscription.status,
    cls: "bg-slate-800 text-slate-400",
  };
  const cancellable = subscription.status === "active" || subscription.status === "past_due";

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40 align-top">
      <td className="px-4 py-3 text-slate-200">{subscription.userNickname}</td>
      <td className="px-4 py-3 text-slate-200">{subscription.planName}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(subscription.startedAt)}</td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(subscription.currentPeriodEnd)}</td>
      <td className="px-4 py-3 text-slate-400 font-mono text-xs">
        {subscription.pgSubscriptionId ?? "-"}
      </td>
      <td className="px-4 py-3">
        {cancellable ? (
          canForceCancel ? (
            showCancelForm ? (
              <form action={formAction} className="flex flex-col gap-2">
                <input type="hidden" name="id" value={subscription.id} />
                <input
                  type="text"
                  name="reason"
                  required
                  placeholder="해지 사유(필수)"
                  className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-xs text-white outline-none focus:border-rose-500"
                />
                <div className="flex gap-2">
                  <button
                    type="submit"
                    disabled={pending}
                    className="rounded-lg border border-rose-900 px-3 py-1 text-xs text-rose-400 hover:bg-rose-950/40 disabled:opacity-50"
                  >
                    강제 해지 확정
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowCancelForm(false)}
                    className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-400 hover:bg-slate-800"
                  >
                    취소
                  </button>
                </div>
              </form>
            ) : (
              <button
                type="button"
                onClick={() => setShowCancelForm(true)}
                className="rounded-lg border border-rose-900 px-3 py-1 text-xs text-rose-400 hover:bg-rose-950/40"
              >
                강제 해지
              </button>
            )
          ) : (
            <span className="text-xs text-slate-600">읽기 전용 권한</span>
          )
        ) : (
          <span className="text-xs text-slate-600">-</span>
        )}
        {state.error && <p className="mt-1 text-xs text-red-400">{state.error}</p>}
      </td>
    </tr>
  );
}
