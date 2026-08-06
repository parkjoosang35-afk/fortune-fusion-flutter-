"use client";

import { useActionState, useState } from "react";
import {
  updateAmuletItem,
  deleteAmuletItem,
  type AmuletFormState,
} from "@/app/actions/amulets";
import ImageUploadField from "@/components/ImageUploadField";

interface AmuletItemRowProps {
  item: {
    id: number;
    name: string;
    gradeId: number;
    effectDescription: string;
    imageUrl: string | null;
    isAiGenerated: boolean;
    pricePoint: number;
    isLimited: boolean;
  };
  grades: { id: number; name: string; code: string }[];
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: AmuletFormState = {};

export default function AmuletItemRow({ item, grades, canWrite, canDelete }: AmuletItemRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateAmuletItem, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteAmuletItem, initialState);

  const gradeName = grades.find((g) => g.id === item.gradeId)?.name ?? "-";

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={item.id} />
            <input
              type="text"
              name="name"
              defaultValue={item.name}
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="gradeId"
              defaultValue={item.gradeId}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {grades.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name}
                </option>
              ))}
            </select>
            <input
              type="number"
              name="pricePoint"
              defaultValue={item.pricePoint}
              min={0}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="effectDescription"
              defaultValue={item.effectDescription}
              className="w-48 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <ImageUploadField
              name="imageUrl"
              category="amulets"
              defaultValue={item.imageUrl}
              compact
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input
                type="checkbox"
                name="isAiGenerated"
                defaultChecked={item.isAiGenerated}
                className="accent-indigo-500"
              />
              AI생성
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input
                type="checkbox"
                name="isLimited"
                defaultChecked={item.isLimited}
                className="accent-indigo-500"
              />
              한정판
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
      <td className="px-4 py-3">
        {item.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={item.imageUrl}
            alt={item.name}
            className="h-12 w-12 rounded-lg border border-slate-300 object-cover"
          />
        ) : (
          <span className="text-slate-500">-</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-700">
        {item.name}
        {item.isLimited && (
          <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
            한정판
          </span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-600">{gradeName}</td>
      <td className="px-4 py-3 max-w-[240px] truncate text-slate-500" title={item.effectDescription}>
        {item.effectDescription}
      </td>
      <td className="px-4 py-3 text-slate-600">{item.pricePoint.toLocaleString()}P</td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
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
              <input type="hidden" name="id" value={item.id} />
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
