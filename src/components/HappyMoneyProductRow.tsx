"use client";

import { useActionState, useState } from "react";
import {
  updateHappyMoneyProduct,
  deleteHappyMoneyProduct,
  type HappyMoneyProductFormState,
} from "@/app/actions/happy-money-products";

interface HappyMoneyProductRowProps {
  product: {
    id: number;
    name: string;
    cashPrice: number;
    happyMoneyAmount: number;
    bonusAmount: number;
    allowedUsageScopes: string;
    isEventGrantable: boolean;
    isManualGrantable: boolean;
    isFeatured: boolean;
    displayPriority: number;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: HappyMoneyProductFormState = {};

export default function HappyMoneyProductRow({ product, canWrite, canDelete }: HappyMoneyProductRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateHappyMoneyProduct, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteHappyMoneyProduct, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={product.id} />
            <input
              type="text"
              name="name"
              defaultValue={product.name}
              className="w-48 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="cashPrice"
              defaultValue={product.cashPrice}
              min={1}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="happyMoneyAmount"
              defaultValue={product.happyMoneyAmount}
              min={1}
              className="w-28 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="bonusAmount"
              defaultValue={product.bonusAmount}
              min={0}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="displayPriority"
              defaultValue={product.displayPriority}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="allowedUsageScopes"
              defaultValue={product.allowedUsageScopes}
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isFeatured" defaultChecked={product.isFeatured} className="accent-indigo-500" /> 추천
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isEventGrantable" defaultChecked={product.isEventGrantable} className="accent-indigo-500" /> 이벤트
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isManualGrantable" defaultChecked={product.isManualGrantable} className="accent-indigo-500" /> 수동지급
            </label>
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={product.isActive} className="accent-indigo-500" /> 활성
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
      <td className="px-4 py-3 text-slate-700">
        {product.name}
        {product.isFeatured && (
          <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">추천</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-600">{product.cashPrice.toLocaleString()}원</td>
      <td className="px-4 py-3 text-slate-600">
        {product.happyMoneyAmount.toLocaleString()}
        {product.bonusAmount > 0 && <span className="text-emerald-700"> +{product.bonusAmount.toLocaleString()}</span>}
      </td>
      <td className="px-4 py-3 text-slate-500">{product.allowedUsageScopes}</td>
      <td className="px-4 py-3 text-slate-500">{product.displayPriority}</td>
      <td className="px-4 py-3">
        {product.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
        )}
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
