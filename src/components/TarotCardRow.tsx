"use client";

import { useActionState, useState } from "react";
import {
  updateTarotCard,
  deleteTarotCard,
  type TarotCardFormState,
} from "@/app/actions/tarot-cards";
import ImageUploadField from "@/components/ImageUploadField";

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
      <tr className="border-b border-slate-200/60 bg-white/30">
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
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="arcanaType"
              defaultValue={card.arcanaType}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              <option value="major">메이저 아르카나</option>
              <option value="minor">마이너 아르카나</option>
            </select>
            <input
              type="number"
              name="sortOrder"
              defaultValue={card.sortOrder}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <ImageUploadField
              name="imageUrl"
              category="tarot-cards"
              defaultValue={card.imageUrl}
            />
            <textarea
              name="uprightMeaning"
              defaultValue={card.uprightMeaning}
              required
              rows={2}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
            />
            <textarea
              name="reversedMeaning"
              defaultValue={card.reversedMeaning}
              required
              rows={2}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
            />
            {updateState.error && (
              <p className="col-span-full text-sm text-red-700">{updateState.error}</p>
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
                className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-600 transition hover:bg-slate-100"
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
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-500">{card.sortOrder}</td>
      <td className="px-4 py-3 font-medium text-slate-900">{card.name}</td>
      <td className="px-4 py-3 text-slate-600">
        {card.arcanaType === "major" ? "메이저" : "마이너"}
      </td>
      <td className="px-4 py-3 text-slate-500">
        <p className="line-clamp-1">정: {card.uprightMeaning}</p>
        <p className="line-clamp-1 text-slate-500">역: {card.reversedMeaning}</p>
      </td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 transition hover:bg-slate-100"
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
                className="rounded-lg border border-red-300/60 px-2 py-1 text-xs text-red-700 transition hover:bg-red-100 disabled:opacity-50"
              >
                {deletePending ? "삭제 중..." : "삭제"}
              </button>
            </form>
          )}
        </div>
        {deleteState.error && (
          <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>
        )}
      </td>
    </tr>
  );
}
