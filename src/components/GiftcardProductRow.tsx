"use client";

import { useActionState, useState } from "react";
import {
  updateGiftcardProduct,
  deleteGiftcardProduct,
  type GiftcardFormState,
} from "@/app/actions/giftcards";

interface GiftcardProductRowProps {
  product: {
    id: number;
    name: string;
    brand: string;
    requiredPoint: number;
    stockCount: number;
    validDays: number;
    imageUrl: string | null;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: GiftcardFormState = {};

export default function GiftcardProductRow({
  product,
  canWrite,
  canDelete,
}: GiftcardProductRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateGiftcardProduct,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteGiftcardProduct,
    initialState
  );

  const isOutOfStock = product.stockCount <= 0;

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={product.id} />
            <input
              type="text"
              name="name"
              defaultValue={product.name}
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="brand"
              defaultValue={product.brand}
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="requiredPoint"
              defaultValue={product.requiredPoint}
              min={0}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="stockCount"
              defaultValue={product.stockCount}
              min={0}
              className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="validDays"
              defaultValue={product.validDays}
              min={1}
              className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="imageUrl"
              defaultValue={product.imageUrl ?? ""}
              placeholder="이미지 URL"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
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
      <td className="px-4 py-3">
        {product.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={product.imageUrl}
            alt={product.name}
            className="h-12 w-12 rounded-lg border border-slate-700 object-cover"
          />
        ) : (
          <span className="text-slate-500">-</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-200">
        {product.name}
        {!product.isActive && (
          <span className="ml-2 rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-500">
            판매중지
          </span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-400">{product.brand}</td>
      <td className="px-4 py-3 text-slate-300">{product.requiredPoint.toLocaleString()}P</td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            isOutOfStock ? "bg-rose-950/60 text-rose-400" : "bg-emerald-950/60 text-emerald-400"
          }`}
        >
          {isOutOfStock ? "품절" : `재고 ${product.stockCount.toLocaleString()}`}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-400">{product.validDays}일</td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
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
              <input type="hidden" name="id" value={product.id} />
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
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
