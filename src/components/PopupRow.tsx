"use client";

import { useActionState, useState } from "react";
import {
  updatePopup,
  deletePopup,
  togglePopupActive,
  type PopupFormState,
} from "@/app/actions/popups";

interface PopupRowProps {
  popup: {
    id: number;
    title: string;
    imageUrl: string | null;
    linkUrl: string | null;
    displayCondition: string | null;
    isActive: boolean;
    startAt: Date;
    endAt: Date;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: PopupFormState = {};

function toLocalInputValue(d: Date): string {
  return d.toISOString().slice(0, 16);
}

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

function parseDisplayCondition(raw: string | null): { once: boolean; segment?: string } {
  if (!raw) return { once: false };
  try {
    const parsed = JSON.parse(raw);
    return { once: !!parsed.once, segment: parsed.segment };
  } catch {
    return { once: false };
  }
}

export default function PopupRow({ popup, canWrite, canDelete }: PopupRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updatePopup, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deletePopup, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    togglePopupActive,
    initialState
  );

  const cond = parseDisplayCondition(popup.displayCondition);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={popup.id} />
            <input
              type="text"
              name="title"
              defaultValue={popup.title}
              className="w-44 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="segment"
              defaultValue={cond.segment ?? ""}
              placeholder="세그먼트(선택)"
              className="w-32 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="imageUrl"
              defaultValue={popup.imageUrl ?? ""}
              placeholder="이미지 URL(선택)"
              className="w-52 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="linkUrl"
              defaultValue={popup.linkUrl ?? ""}
              placeholder="링크 URL(선택)"
              className="w-52 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(popup.startAt)}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(popup.endAt)}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input type="checkbox" name="once" defaultChecked={cond.once} className="accent-indigo-500" />
              1회성
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={popup.isActive}
                className="accent-indigo-500"
              />
              활성
            </label>
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
              className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
            >
              취소
            </button>
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-200">
        {popup.title}
        {popup.linkUrl && (
          <>
            <br />
            <a
              href={popup.linkUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="max-w-[220px] truncate text-xs text-indigo-400 underline hover:text-indigo-300"
              title={popup.linkUrl}
            >
              {popup.linkUrl}
            </a>
          </>
        )}
      </td>
      <td className="px-4 py-3">
        {popup.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={popup.imageUrl}
            alt={popup.title}
            className="h-10 w-16 rounded-md border border-slate-700 object-cover"
          />
        ) : (
          <span className="text-xs text-slate-500">텍스트 전용</span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-300">
        {cond.once ? "1회성" : "반복"}
        {cond.segment && (
          <>
            <br />
            <span className="text-slate-500">{cond.segment}</span>
          </>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {formatDate(popup.startAt)}
        <br />
        {formatDate(popup.endAt)}
      </td>
      <td className="px-4 py-3">
        {popup.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
            활성
          </span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
            비활성
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={popup.id} />
              <input type="hidden" name="isActive" value={(!popup.isActive).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50"
              >
                {popup.isActive ? "비활성으로" : "활성으로"}
              </button>
            </form>
          )}
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
            >
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={popup.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {toggleState.error && <p className="mt-1 text-xs text-red-400">{toggleState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
