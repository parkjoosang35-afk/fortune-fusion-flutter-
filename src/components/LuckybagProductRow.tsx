"use client";

import { useActionState, useState } from "react";
import {
  updateLuckybagProduct,
  deleteLuckybagProduct,
  type LuckybagFormState,
} from "@/app/actions/luckybag";
import ImageUploadField from "@/components/ImageUploadField";

interface LuckybagProductRowProps {
  product: {
    id: number;
    name: string;
    pricePoint: number;
    imageUrl: string | null;
    seasonId: number | null;
    isActive: boolean;
  };
  seasons: { id: number; name: string }[];
  probabilitySum: number;
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: LuckybagFormState = {};

export default function LuckybagProductRow({
  product,
  seasons,
  probabilitySum,
  canWrite,
  canDelete,
}: LuckybagProductRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateLuckybagProduct,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteLuckybagProduct,
    initialState
  );

  const seasonName = seasons.find((s) => s.id === product.seasonId)?.name ?? "(상시 판매)";
  const isSumComplete = Math.abs(probabilitySum - 100) < 0.0001;

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={product.id} />
            <input
              type="text"
              name="name"
              defaultValue={product.name}
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="pricePoint"
              defaultValue={product.pricePoint}
              min={0}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="seasonId"
              defaultValue={product.seasonId ?? ""}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              <option value="">(상시 판매)</option>
              {seasons.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
            <ImageUploadField
              name="imageUrl"
              category="luckybag"
              defaultValue={product.imageUrl}
              compact
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={product.isActive}
                className="accent-indigo-500"
              />
              판매중
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
        {product.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={product.imageUrl}
            alt={product.name}
            className="h-12 w-12 rounded-lg border border-slate-300 object-cover"
          />
        ) : (
          <span className="text-slate-500">-</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-700">
        {product.name}
        {!product.isActive && (
          <span className="ml-2 rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
            판매중지
          </span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-600">{product.pricePoint.toLocaleString()}P</td>
      <td className="px-4 py-3 text-slate-500">{seasonName}</td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            isSumComplete
              ? "bg-emerald-100 text-emerald-700"
              : "bg-amber-100 text-amber-700"
          }`}
        >
          확률 합계 {probabilitySum}%{!isSumComplete && " (미완성)"}
        </span>
      </td>
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
              <input type="hidden" name="id" value={product.id} />
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
