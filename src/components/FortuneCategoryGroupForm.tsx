"use client";

// [운세 카테고리 확장] 그룹(라벨/설명/정렬순서) 편집 폼 + 노출 토글.
import { useActionState } from "react";
import {
  updateFortuneCategoryGroup,
  toggleFortuneCategoryGroupVisible,
  type CategoryActionState,
} from "@/app/actions/fortune-categories";

const initialState: CategoryActionState = {};

interface Props {
  code: string;
  label: string;
  description: string;
  displayOrder: number;
  isVisible: boolean;
  categoryCount: number;
  canWrite: boolean;
}

export default function FortuneCategoryGroupForm({
  code,
  label,
  description,
  displayOrder,
  isVisible,
  categoryCount,
  canWrite,
}: Props) {
  const [state, formAction, pending] = useActionState(updateFortuneCategoryGroup, initialState);
  const [visState, visAction, visPending] = useActionState(
    toggleFortuneCategoryGroupVisible,
    initialState
  );

  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900 p-5">
      <div className="mb-3 flex items-center justify-between">
        <span className="text-xs text-slate-500">
          code: <span className="font-mono text-slate-400">{code}</span> · 카테고리{" "}
          {categoryCount}개
        </span>
        <form action={visAction}>
          <input type="hidden" name="code" value={code} />
          <button
            type="submit"
            disabled={!canWrite || visPending}
            className={`rounded-full px-2 py-0.5 text-xs font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${
              isVisible
                ? "bg-emerald-950/60 text-emerald-400 hover:bg-emerald-900/60"
                : "bg-slate-800 text-slate-500 hover:bg-slate-700"
            }`}
          >
            {visPending ? "..." : isVisible ? "노출중" : "숨김"}
          </button>
        </form>
      </div>

      <form action={formAction} className="space-y-3">
        <input type="hidden" name="code" value={code} />
        <div className="grid grid-cols-1 gap-3 md:grid-cols-[2fr_3fr_1fr]">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-400">그룹명</label>
            <input
              name="label"
              defaultValue={label}
              disabled={!canWrite}
              className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 disabled:opacity-60"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-400">설명</label>
            <input
              name="description"
              defaultValue={description}
              disabled={!canWrite}
              className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 disabled:opacity-60"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-400">정렬순서</label>
            <input
              type="number"
              name="displayOrder"
              defaultValue={displayOrder}
              disabled={!canWrite}
              className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 disabled:opacity-60"
            />
          </div>
        </div>

        {state.error && <p className="text-xs text-red-400">{state.error}</p>}
        {state.success && <p className="text-xs text-emerald-400">저장되었습니다.</p>}

        {canWrite && (
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "저장"}
          </button>
        )}
      </form>
    </div>
  );
}
