"use client";

import { useActionState, useRef } from "react";
import { issueCouponToUser, type CouponFormState } from "@/app/actions/coupons";

interface CouponIssueFormProps {
  canWrite: boolean;
  coupons: { id: number; code: string }[];
  users: { id: number; nickname: string }[];
}

const initialState: CouponFormState = {};

export default function CouponIssueForm({ canWrite, coupons, users }: CouponIssueFormProps) {
  const [state, formAction, pending] = useActionState(issueCouponToUser, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) {
    return (
      <p className="rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-500">
        쿠폰 발급 권한이 없습니다.
      </p>
    );
  }

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <label className="flex flex-col gap-1 text-xs text-slate-400 md:col-span-2">
        쿠폰 선택
        <select
          name="couponId"
          required
          defaultValue=""
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          <option value="" disabled>
            쿠폰을 선택해주세요
          </option>
          {coupons.map((c) => (
            <option key={c.id} value={c.id}>
              {c.code}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-xs text-slate-400 md:col-span-2">
        발급 대상 회원
        <select
          name="userId"
          required
          defaultValue=""
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          <option value="" disabled>
            회원을 선택해주세요
          </option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {u.nickname} (#{u.id})
            </option>
          ))}
        </select>
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          쿠폰이 발급되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "발급 중..." : "쿠폰 발급"}
        </button>
      </div>
    </form>
  );
}
