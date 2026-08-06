"use client";

// "힐링 문구" 관리자 콘텐츠 테이블 행. LuckyNumberRow.tsx 구조를 참고하되
// 미디어 필드가 없고 content/author/category 텍스트 필드만 다룬다.
import { useActionState, useState } from "react";
import {
  updateHealingQuote,
  deleteHealingQuote,
  toggleHealingQuoteActive,
  type HealingQuoteFormState,
} from "@/app/actions/healingQuote";

interface HealingQuoteRowProps {
  quote: {
    id: number;
    content: string;
    author: string | null;
    category: string;
    sortOrder: number;
    isActive: boolean;
    startAt: Date | null;
    endAt: Date | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: HealingQuoteFormState = {};

const CATEGORY_LABEL: Record<string, string> = {
  healing: "힐링 문구",
  quote: "좋은 글귀",
  encouragement: "응원의 한마디",
  wisdom: "긍정 명언",
};

function toLocalInputValue(d: Date | null): string {
  if (!d) return "";
  return d.toISOString().slice(0, 16);
}

function formatDate(d: Date | null): string {
  if (!d) return "-";
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function HealingQuoteRow({ quote, canWrite, canDelete }: HealingQuoteRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateHealingQuote, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteHealingQuote, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleHealingQuoteActive,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={quote.id} />
            <textarea
              name="content"
              defaultValue={quote.content}
              rows={2}
              className="w-full rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="text"
              name="author"
              defaultValue={quote.author ?? ""}
              placeholder="출처/저자(선택)"
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <select
              name="category"
              defaultValue={quote.category}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            >
              <option value="healing">힐링 문구</option>
              <option value="quote">좋은 글귀</option>
              <option value="encouragement">응원의 한마디</option>
              <option value="wisdom">긍정 명언</option>
            </select>
            <input
              type="number"
              name="sortOrder"
              defaultValue={quote.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(quote.startAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(quote.endAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={quote.isActive}
                className="accent-purple-500"
              />
              활성
            </label>
            <button
              type="submit"
              disabled={updatePending}
              className="rounded-lg bg-purple-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-purple-500 disabled:opacity-50"
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
      <td className="px-4 py-3 text-slate-700">
        <p className="max-w-[320px] truncate" title={quote.content}>
          {quote.content}
        </p>
        {quote.author && <p className="mt-0.5 text-xs text-slate-500">- {quote.author}</p>}
      </td>
      <td className="px-4 py-3">
        <span className="rounded-full bg-white px-1.5 py-0.5 text-[10px] text-slate-500">
          {CATEGORY_LABEL[quote.category] ?? quote.category}
        </span>
        <span className="ml-1 text-xs text-slate-500">#{quote.sortOrder}</span>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {formatDate(quote.startAt)}
        <br />
        {formatDate(quote.endAt)}
      </td>
      <td className="px-4 py-3">
        {quote.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
            활성
          </span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
            비활성
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={quote.id} />
              <input type="hidden" name="isActive" value={(!quote.isActive).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
              >
                {quote.isActive ? "비활성으로" : "활성으로"}
              </button>
            </form>
          )}
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
              <input type="hidden" name="id" value={quote.id} />
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
        {toggleState.error && <p className="mt-1 text-xs text-red-700">{toggleState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
