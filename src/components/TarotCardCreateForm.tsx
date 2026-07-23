"use client";

import { useActionState, useRef } from "react";
import { createTarotCard, type TarotCardFormState } from "@/app/actions/tarot-cards";

const initialState: TarotCardFormState = {};

export default function TarotCardCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createTarotCard, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-2"
    >
      <h2 className="col-span-full text-sm font-semibold text-white">새 타로카드 추가</h2>
      <input
        type="text"
        name="name"
        placeholder="카드 이름 (예: The Fool (광대))"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <select
        name="arcanaType"
        defaultValue="major"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="major">메이저 아르카나</option>
        <option value="minor">마이너 아르카나</option>
      </select>
      <input
        type="number"
        name="sortOrder"
        placeholder="정렬 순서"
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="imageUrl"
        placeholder="이미지 URL (선택)"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <textarea
        name="uprightMeaning"
        placeholder="정방향 의미"
        required
        rows={2}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <textarea
        name="reversedMeaning"
        placeholder="역방향 의미"
        required
        rows={2}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          카드가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "카드 추가"}
        </button>
      </div>
    </form>
  );
}
