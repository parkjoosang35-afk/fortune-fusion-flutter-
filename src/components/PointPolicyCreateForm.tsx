"use client";

import { useActionState, useRef } from "react";
import { createPointPolicy, type PointPolicyFormState } from "@/app/actions/point-policies";

const initialState: PointPolicyFormState = {};

export default function PointPolicyCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createPointPolicy, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-5"
    >
      <h2 className="col-span-full text-sm font-semibold text-white">새 포인트 정책 추가</h2>
      <input
        type="text"
        name="sourceType"
        placeholder="source_type (예: ai_saju_request)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="number"
        name="amount"
        placeholder="적립/차감액"
        required
        min={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="dailyLimit"
        placeholder="1일 한도(무료횟수/지급횟수, 선택)"
        min={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          정책이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <p className="mb-2 text-xs text-slate-500">
          적립형(earn) source_type: attendance/mission/event/community 등 — amount=지급액,
          daily_limit=1일 최대 지급횟수 · 차감형(spend, AI기능 무료/유료 정책) source_type:
          ai_saju_request 등 — amount=차감포인트, daily_limit=1일 무료횟수
        </p>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "정책 추가"}
        </button>
      </div>
    </form>
  );
}
