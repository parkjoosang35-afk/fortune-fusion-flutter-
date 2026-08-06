"use client";

import { useActionState, useState } from "react";
import { updateFaq, deleteFaq, type FaqFormState } from "@/app/actions/faqs";

interface FaqRowProps {
  faq: {
    id: number;
    category: string;
    question: string;
    answer: string;
    sortOrder: number;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: FaqFormState = {};

export default function FaqRow({ faq, canWrite, canDelete }: FaqRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateFaq, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteFaq, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={4} className="px-4 py-3">
          <form action={updateAction} className="flex flex-col gap-2">
            <input type="hidden" name="id" value={faq.id} />
            <div className="flex flex-wrap gap-2">
              <input
                type="text"
                name="category"
                defaultValue={faq.category}
                className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
              />
              <input
                type="number"
                name="sortOrder"
                defaultValue={faq.sortOrder}
                min={0}
                className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
              />
            </div>
            <input
              type="text"
              name="question"
              defaultValue={faq.question}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <textarea
              name="answer"
              defaultValue={faq.answer}
              rows={3}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <div className="flex items-center gap-2">
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
            </div>
            {updateState.error && <p className="text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3">
        <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-600">
          {faq.category}
        </span>
      </td>
      <td className="px-4 py-3">
        <div className="font-medium text-slate-700">{faq.question}</div>
        <p className="mt-1 max-w-xl truncate text-xs text-slate-500">{faq.answer}</p>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">#{faq.sortOrder}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
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
              <input type="hidden" name="id" value={faq.id} />
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
