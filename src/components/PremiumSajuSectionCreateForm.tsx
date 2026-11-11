"use client";

import { useActionState, useRef } from "react";
import {
  createPremiumSajuSection,
  type PremiumSajuFormState,
} from "@/app/actions/premium-saju";

const initialState: PremiumSajuFormState = {};

export default function PremiumSajuSectionCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createPremiumSajuSection, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-2"
    >
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 섹션 추가</h2>
      <input
        type="text"
        name="sectionKey"
        placeholder="섹션 키 (영문소문자_숫자, 예: overview)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="sectionLabel"
        placeholder="섹션 이름 (예: 총론)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="sortOrder"
        placeholder="PDF 배치 순서(숫자가 작을수록 앞)"
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <textarea
        name="templateBody"
        placeholder="이 섹션의 LLM 프롬프트 본문"
        required
        rows={3}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <div className="col-span-full flex items-center justify-between">
        {state.error && <p className="text-xs text-red-700">{state.error}</p>}
        <button
          type="submit"
          disabled={pending}
          className="ml-auto rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {pending ? "추가 중..." : "섹션 추가"}
        </button>
      </div>
    </form>
  );
}
