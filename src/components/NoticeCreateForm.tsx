"use client";

import { useActionState, useRef } from "react";
import { createNotice, type NoticeFormState } from "@/app/actions/notices";

const initialState: NoticeFormState = {};

export default function NoticeCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createNotice, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4"
    >
      <h3 className="text-sm font-semibold text-slate-900">새 공지사항 추가</h3>
      <input
        type="text"
        name="title"
        placeholder="공지사항 제목"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <textarea
        name="content"
        placeholder="공지사항 내용"
        required
        rows={4}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isPinned" className="accent-indigo-500" />
        상단 고정
      </label>

      {state.error && (
        <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          공지사항이 추가되었습니다.
        </p>
      )}

      <div>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "공지사항 추가"}
        </button>
      </div>
    </form>
  );
}
