"use client";

// [운세 카테고리 확장] 카테고리 isActive/isVisible/isFeatured 즉시 토글 버튼.
// PromptDeployButton.tsx의 useActionState 폼 패턴을 그대로 재사용한다.
import { useActionState } from "react";
import {
  toggleFortuneCategoryFlag,
  type CategoryActionState,
} from "@/app/actions/fortune-categories";

const initialState: CategoryActionState = {};

interface Props {
  categoryKey: string;
  field: "isActive" | "isVisible" | "isFeatured";
  value: boolean;
  canWrite: boolean;
  labelOn: string;
  labelOff: string;
}

export default function FortuneCategoryToggleButton({
  categoryKey,
  field,
  value,
  canWrite,
  labelOn,
  labelOff,
}: Props) {
  const [state, formAction, pending] = useActionState(
    toggleFortuneCategoryFlag,
    initialState
  );

  if (!canWrite) {
    return (
      <span
        className={`rounded-full px-2 py-0.5 text-xs font-medium ${
          value ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"
        }`}
      >
        {value ? labelOn : labelOff}
      </span>
    );
  }

  return (
    <form action={formAction} className="inline-block">
      <input type="hidden" name="categoryKey" value={categoryKey} />
      <input type="hidden" name="field" value={field} />
      <button
        type="submit"
        disabled={pending}
        className={`rounded-full px-2 py-0.5 text-xs font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${
          value
            ? "bg-emerald-100 text-emerald-700 hover:bg-emerald-100"
            : "bg-white text-slate-500 hover:bg-slate-200"
        }`}
        title="클릭하여 토글"
      >
        {pending ? "..." : value ? labelOn : labelOff}
      </button>
      {state.error && <p className="mt-1 text-xs text-red-700">{state.error}</p>}
    </form>
  );
}
