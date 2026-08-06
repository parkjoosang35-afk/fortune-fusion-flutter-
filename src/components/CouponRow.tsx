"use client";

import { useActionState, useState } from "react";
import { updateCoupon, deleteCoupon, type CouponFormState } from "@/app/actions/coupons";

interface CouponRowProps {
  coupon: {
    id: number;
    code: string;
    discountType: string;
    discountValue: number;
    validFrom: Date;
    validTo: Date;
    usageLimit: number | null;
    issuedCount: number;
    isExpired: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: CouponFormState = {};

function fmtDateInput(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export default function CouponRow({ coupon, canWrite, canDelete }: CouponRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateCoupon, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteCoupon, initialState);

  const discountLabel =
    coupon.discountType === "rate"
      ? `${coupon.discountValue}%`
      : `${coupon.discountValue.toLocaleString()}P`;
  const limitReached = coupon.usageLimit != null && coupon.issuedCount >= coupon.usageLimit;

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={coupon.id} />
            <span className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-xs text-slate-500">
              {coupon.code} (코드 수정 불가)
            </span>
            <input
              type="number"
              name="discountValue"
              defaultValue={coupon.discountValue}
              min={0}
              step="0.01"
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="date"
              name="validFrom"
              defaultValue={fmtDateInput(coupon.validFrom)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="date"
              name="validTo"
              defaultValue={fmtDateInput(coupon.validTo)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="usageLimit"
              defaultValue={coupon.usageLimit ?? ""}
              min={1}
              placeholder="무제한"
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
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
      <td className="px-4 py-3 font-mono text-slate-700">{coupon.code}</td>
      <td className="px-4 py-3 text-slate-600">{discountLabel}</td>
      <td className="px-4 py-3 text-slate-500">
        {fmtDateInput(coupon.validFrom)} ~ {fmtDateInput(coupon.validTo)}
      </td>
      <td className="px-4 py-3 text-slate-500">
        {coupon.issuedCount.toLocaleString()} / {coupon.usageLimit?.toLocaleString() ?? "무제한"}
      </td>
      <td className="px-4 py-3">
        {coupon.isExpired ? (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">만료됨</span>
        ) : limitReached ? (
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">소진됨</span>
        ) : (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">진행중</span>
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
              <input type="hidden" name="id" value={coupon.id} />
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
