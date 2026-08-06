"use client";

import { useActionState, useState } from "react";
import { updateFeatureAssetBinding, type FeatureAssetBindingFormState } from "@/app/actions/feature-asset-bindings";

interface FeatureAssetBindingRowProps {
  binding: {
    id: number;
    scope: string;
    featureGroup: string;
    primaryAsset: string;
    secondaryAssets: string | null;
    accessType: string;
    notes: string | null;
    isActive: boolean;
    editableByAdmin: boolean;
  };
  canWrite: boolean;
}

const ASSET_LABEL: Record<string, string> = {
  open_pass: "열림패스",
  happy_money: "행복머니",
  luck_pouch: "복주머니",
  free: "무료",
};

const ACCESS_TYPE_OPTIONS = [
  { value: "free", label: "무료(free)" },
  { value: "open_pass", label: "열림패스(open_pass)" },
  { value: "happy_money", label: "행복머니(happy_money)" },
  { value: "luck_pouch", label: "복주머니(luck_pouch)" },
  { value: "mixed_limited", label: "혼합/부분무료(mixed_limited)" },
];

const initialState: FeatureAssetBindingFormState = {};

export default function FeatureAssetBindingRow({ binding, canWrite }: FeatureAssetBindingRowProps) {
  const [editing, setEditing] = useState(false);
  const [state, formAction, pending] = useActionState(updateFeatureAssetBinding, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={6} className="px-4 py-3">
          <form action={formAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={binding.id} />
            <span className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-xs text-slate-500">
              {binding.scope}
            </span>
            <select
              name="accessType"
              defaultValue={binding.accessType}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {ACCESS_TYPE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
            <input
              type="text"
              name="secondaryAssets"
              defaultValue={binding.secondaryAssets ?? ""}
              placeholder="보조 자산(콤마구분)"
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="notes"
              defaultValue={binding.notes ?? ""}
              placeholder="비고"
              className="w-56 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={binding.isActive} className="accent-indigo-500" /> 활성
            </label>
            <button
              type="submit"
              disabled={pending}
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
            {state.error && <p className="w-full text-xs text-red-700">{state.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 font-mono text-xs text-slate-600">{binding.scope}</td>
      <td className="px-4 py-3 text-slate-500">{binding.featureGroup}</td>
      <td className="px-4 py-3 text-slate-700">{ASSET_LABEL[binding.primaryAsset] ?? binding.primaryAsset}</td>
      <td className="px-4 py-3 text-slate-500">
        {ACCESS_TYPE_OPTIONS.find((o) => o.value === binding.accessType)?.label ?? binding.accessType}
      </td>
      <td className="px-4 py-3">
        {binding.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
        )}
      </td>
      <td className="px-4 py-3">
        {canWrite && binding.editableByAdmin ? (
          <button
            onClick={() => setEditing(true)}
            className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100"
          >
            수정
          </button>
        ) : (
          <span className="text-xs text-slate-600">수정불가</span>
        )}
      </td>
    </tr>
  );
}
