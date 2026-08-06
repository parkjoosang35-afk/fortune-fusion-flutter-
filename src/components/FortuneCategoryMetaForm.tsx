"use client";

// [운세 카테고리 확장] 카테고리 메타(제목/설명/아이콘/배지/라우트/결과길이 안내) 편집 폼.
import { useActionState } from "react";
import {
  updateFortuneCategoryMeta,
  type CategoryActionState,
} from "@/app/actions/fortune-categories";

const initialState: CategoryActionState = {};

interface Props {
  categoryKey: string;
  title: string;
  shortDescription: string;
  icon: string;
  badgeLabel: string;
  route: string;
  resultLengthHint: string;
  groups: { id: number; label: string }[];
  currentGroupId: number | null;
  canWrite: boolean;
}

export default function FortuneCategoryMetaForm({
  categoryKey,
  title,
  shortDescription,
  icon,
  badgeLabel,
  route,
  resultLengthHint,
  groups,
  currentGroupId,
  canWrite,
}: Props) {
  const [state, formAction, pending] = useActionState(updateFortuneCategoryMeta, initialState);

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="categoryKey" value={categoryKey} />

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">제목</label>
        <input
          name="title"
          defaultValue={title}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">
          카드 설명(전체보기 카드에 노출)
        </label>
        <input
          name="shortDescription"
          defaultValue={shortDescription}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-600">
            아이콘(Material icon 이름)
          </label>
          <input
            name="icon"
            defaultValue={icon}
            disabled={!canWrite}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-600">배지 문구</label>
          <input
            name="badgeLabel"
            defaultValue={badgeLabel}
            placeholder="NEW / 추천 / 대표"
            disabled={!canWrite}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
          />
        </div>
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">
          Flutter 라우트(비워두면 &quot;준비중&quot;으로 노출)
        </label>
        <input
          name="route"
          defaultValue={route}
          placeholder="/ai-fortune/xxx/input"
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-mono text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">
          결과 길이 안내(관리자용 메모)
        </label>
        <input
          name="resultLengthHint"
          defaultValue={resultLengthHint}
          placeholder="400~500자"
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        />
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">그룹</label>
        <select
          name="groupId"
          defaultValue={currentGroupId ?? ""}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-60"
        >
          <option value="">(그룹 없음)</option>
          {groups.map((g) => (
            <option key={g.id} value={g.id}>
              {g.label}
            </option>
          ))}
        </select>
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          저장되었습니다.
        </p>
      )}

      {canWrite && (
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "저장 중..." : "저장"}
        </button>
      )}
    </form>
  );
}
