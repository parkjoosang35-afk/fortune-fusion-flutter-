"use client";

import { useActionState, useState } from "react";
import {
  updatePassPolicy,
  deletePassPolicy,
  type PassPolicyFormState,
} from "@/app/actions/pass-policies";

interface PassPolicyRowProps {
  policy: {
    id: number;
    name: string;
    passType: string;
    durationMin: number;
    dailyLimit: number | null;
    ctaText: string | null;
    bannerImageUrl: string | null;
    linkUrl: string | null;
    bonusPoint: number;
    isActive: boolean;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const PASS_TYPE_OPTIONS = [
  { value: "ad", label: "광고 시청" },
  { value: "partner", label: "파트너 제휴" },
  { value: "subscription", label: "구독" },
  { value: "event", label: "이벤트" },
];

const PASS_TYPE_BADGE: Record<string, string> = {
  ad: "bg-sky-950/60 text-sky-400",
  partner: "bg-purple-950/60 text-purple-400",
  subscription: "bg-emerald-950/60 text-emerald-400",
  event: "bg-amber-950/60 text-amber-400",
};

const initialState: PassPolicyFormState = {};

export default function PassPolicyRow({ policy, canWrite, canDelete }: PassPolicyRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updatePassPolicy, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deletePassPolicy, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={policy.id} />
            <input
              type="text"
              name="name"
              defaultValue={policy.name}
              className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <select
              name="passType"
              defaultValue={policy.passType}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              {PASS_TYPE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
            <input
              type="number"
              name="durationMin"
              defaultValue={policy.durationMin}
              min={1}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="dailyLimit"
              defaultValue={policy.dailyLimit ?? ""}
              min={0}
              placeholder="한도(선택)"
              className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="bonusPoint"
              defaultValue={policy.bonusPoint}
              min={0}
              placeholder="보너스P"
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="linkUrl"
              defaultValue={policy.linkUrl ?? ""}
              placeholder="링크URL"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="ctaText"
              defaultValue={policy.ctaText ?? ""}
              placeholder="CTA문구"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="text"
              name="bannerImageUrl"
              defaultValue={policy.bannerImageUrl ?? ""}
              placeholder="배너URL"
              className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={policy.isActive}
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
      <td className="px-4 py-3 text-slate-200">{policy.name}</td>
      <td className="px-4 py-3">
        <span
          className={`rounded-full px-2 py-0.5 text-xs ${
            PASS_TYPE_BADGE[policy.passType] ?? "bg-slate-800 text-slate-400"
          }`}
        >
          {PASS_TYPE_OPTIONS.find((o) => o.value === policy.passType)?.label ?? policy.passType}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-300">{policy.durationMin}분</td>
      <td className="px-4 py-3 text-slate-400">
        {policy.dailyLimit != null ? policy.dailyLimit.toLocaleString() : "무제한"}
      </td>
      <td className="px-4 py-3 text-slate-300">
        {policy.bonusPoint > 0 ? `+${policy.bonusPoint.toLocaleString()}P` : "-"}
      </td>
      <td className="px-4 py-3">
        {policy.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">활성</span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">비활성</span>
        )}
      </td>
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
              <input type="hidden" name="id" value={policy.id} />
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
