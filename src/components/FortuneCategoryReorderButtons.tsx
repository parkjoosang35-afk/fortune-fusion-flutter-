"use client";

// [운세 카테고리 확장] 그룹 내 카테고리 정렬 순서(위/아래) 이동 버튼.
import { useActionState } from "react";
import {
  reorderFortuneCategory,
  type CategoryActionState,
} from "@/app/actions/fortune-categories";

const initialState: CategoryActionState = {};

interface Props {
  categoryKey: string;
  canWrite: boolean;
}

export default function FortuneCategoryReorderButtons({ categoryKey, canWrite }: Props) {
  const [upState, upAction, upPending] = useActionState(reorderFortuneCategory, initialState);
  const [downState, downAction, downPending] = useActionState(reorderFortuneCategory, initialState);

  if (!canWrite) return null;

  return (
    <div className="flex items-center gap-1">
      <form action={upAction}>
        <input type="hidden" name="categoryKey" value={categoryKey} />
        <input type="hidden" name="direction" value="up" />
        <button
          type="submit"
          disabled={upPending}
          className="rounded border border-slate-300 px-1.5 py-0.5 text-xs text-slate-500 hover:bg-slate-100 disabled:opacity-50"
          title="위로"
        >
          ↑
        </button>
      </form>
      <form action={downAction}>
        <input type="hidden" name="categoryKey" value={categoryKey} />
        <input type="hidden" name="direction" value="down" />
        <button
          type="submit"
          disabled={downPending}
          className="rounded border border-slate-300 px-1.5 py-0.5 text-xs text-slate-500 hover:bg-slate-100 disabled:opacity-50"
          title="아래로"
        >
          ↓
        </button>
      </form>
      {(upState.error || downState.error) && (
        <span className="text-xs text-red-700">{upState.error || downState.error}</span>
      )}
    </div>
  );
}
