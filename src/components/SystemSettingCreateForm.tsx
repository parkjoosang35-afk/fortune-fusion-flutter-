"use client";

import { useActionState, useRef } from "react";
import { createSystemSetting, type SystemSettingFormState } from "@/app/actions/system-settings";

const initialState: SystemSettingFormState = {};

export default function SystemSettingCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createSystemSetting, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 설정값 추가</h3>
      <input
        type="text"
        name="key"
        placeholder="설정 키 (예: maintenance_mode)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="value"
        placeholder="설정값 (예: false, 1.2.0)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="description"
        placeholder="설명(선택)"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? "추가 중..." : "설정값 추가"}
      </button>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          설정값이 추가되었습니다.
        </p>
      )}
    </form>
  );
}
