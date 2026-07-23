"use client";

import { useActionState, useState } from "react";
import {
  updateTarotCard,
  deleteTarotCard,
  type TarotCardFormState,
} from "@/app/actions/tarot-cards";

const initialState: TarotCardFormState = {};

interface TarotCardRowProps {
  card: {
    id: number;
    name: string;
    arcanaType: string;
    uprightMeaning: string;
    reversedMeaning: string;
    sortOrder: number;
    imageUrl: string | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

export default function TarotCardRow({ card, canWrite, canDelete }: TarotCardRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateTarotCard,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteTarotCard,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={5} className="px-4 py-4">
          <form
            action={async (formData) => {
              await updateAction(formData);
              setEditing(false);
            }}
            className="grid grid-cols-1 gap-3 md:grid-cols-2"
          >
            <input type="hidden" name="id" value={card.id} />
            <input
              type="text"
              name="name"
              defaultValue={card.name}
              required
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            />
            <select
              name="arcanaType"
              defaultValue={card.arcanaType}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            >
              <option value="major">메이저 아르카나</option>
              <option value="minor">마이너 아르카나</option>
            </select>
            <input
              type="number"
              name="sortOrder"
              defaultValue={card.sortOrder}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="imageUrl"
              defaultValue={card.imageUrl ?? ""}
              placeholder="이미지 URL"
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            />
            <textarea
              name="uprightMeaning"
              defaultValue={card.uprightMeaning}
              required
              rows={2}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
            />
            <textarea
              name="reversedMeaning"
              defaultValue={card.reversedMeaning}
              required
              rows={2}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
            />
            {updateState.error && (
              <p className="col-span-full text-sm text-red-400">{updateState.error}</p>
            )}
            <div className="col-span-full flex gap-2">
              <button
                type="submit"
                disabled={updatePending}
                className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:opacity-50"
              >
                {updatePending ? "저장 중..." : "저장"}
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded-lg border border-slate-700 px-4 py-2 text-sm text-slate-300 transition hover:bg-slate-800"
              >
                취소
              </button>
            </div>
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-400">{card.sortOrder}</td>
      <td className="px-4 py-3 font-medium text-white">{card.name}</td>
      <td className="px-4 py-3 text-slate-300">
        {card.arcanaType === "major" ? "메이저" : "마이너"}
      </td>
      <td className="px-4 py-3 text-slate-400">
        <p className="line-clamp-1">정: {card.uprightMeaning}</p>
        <p className="line-clamp-1 text-slate-500">역: {card.reversedMeaning}</p>
      </td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-700 px-2 py-1 text-xs text-slate-300 transition hover:bg-slate-800"
            >
              편집
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={card.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-900/60 px-2 py-1 text-xs text-red-400 transition hover:bg-red-950/40 disabled:opacity-50"
              >
                {deletePending ? "삭제 중..." : "삭제"}
              </button>
            </form>
          )}
        </div>
        {deleteState.error && (
          <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>
        )}
      </td>
    </tr>
  );
}
