"use client";

import { useActionState, useRef } from "react";
import { createCounselor, type DowanyeoFormState } from "@/app/actions/dowanyeo";

const initialState: DowanyeoFormState = {};

export default function DowanyeoCounselorForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createCounselor, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-3"
    >
      <h2 className="col-span-full text-sm font-semibold text-slate-900">카운슬러 등록</h2>
      <input
        type="text"
        name="name"
        placeholder="이름"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="specialty"
        placeholder="전문 분야(예: 애정운 전문)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="introBody"
        placeholder="소개(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <div className="col-span-full flex items-center justify-between">
        {state.error && <p className="text-xs text-red-700">{state.error}</p>}
        <button
          type="submit"
          disabled={pending}
          className="ml-auto rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {pending ? "등록 중..." : "등록"}
        </button>
      </div>
    </form>
  );
}
