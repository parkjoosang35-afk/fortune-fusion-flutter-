"use client";

import { useActionState, useRef } from "react";
import { createBanner, type BannerFormState } from "@/app/actions/banners";

const initialState: BannerFormState = {};

const POSITION_OPTIONS = [
  { value: "home_top", label: "홈 상단(home_top)" },
  { value: "home_middle", label: "홈 중단(home_middle)" },
  { value: "home_bottom", label: "홈 하단(home_bottom)" },
];

export default function BannerCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createBanner, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">
        새 배너(제휴 광고) 추가
      </h3>
      <input
        type="text"
        name="title"
        placeholder="배너 제목 (예: 쿠팡파트너스 - OO 상품)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="positionCode"
        defaultValue="home_top"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        {POSITION_OPTIONS.map((p) => (
          <option key={p.value} value={p.value}>
            {p.label}
          </option>
        ))}
      </select>
      <input
        type="number"
        name="sortOrder"
        placeholder="노출 순서"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="imageUrl"
        placeholder="이미지 URL (배너 썸네일)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="linkUrl"
        placeholder="제휴 링크 URL (쿠팡파트너스 등, 선택)"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        시작일시(선택)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        종료일시(선택)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화(노출)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          배너가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "배너 추가"}
        </button>
      </div>
    </form>
  );
}
