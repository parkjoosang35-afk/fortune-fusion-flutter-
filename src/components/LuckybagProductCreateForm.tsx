"use client";

import { useActionState, useRef, useState } from "react";
import { createLuckybagProduct, type LuckybagFormState } from "@/app/actions/luckybag";
import ImageUploadField from "@/components/ImageUploadField";

interface LuckybagProductCreateFormProps {
  canWrite: boolean;
  seasons: { id: number; name: string }[];
}

const initialState: LuckybagFormState = {};

export default function LuckybagProductCreateForm({
  canWrite,
  seasons,
}: LuckybagProductCreateFormProps) {
  const [state, formAction, pending] = useActionState(createLuckybagProduct, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [uploadFieldKey, setUploadFieldKey] = useState(0);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setUploadFieldKey((k) => k + 1);
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 복주머니 상품 추가</h3>
      <input
        type="text"
        name="name"
        placeholder="상품명"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="number"
        name="pricePoint"
        placeholder="가격(포인트)"
        min={0}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <select
        name="seasonId"
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="">(상시 판매 — 시즌 없음)</option>
        {seasons.map((s) => (
          <option key={s.id} value={s.id}>
            {s.name}
          </option>
        ))}
      </select>
      <ImageUploadField
        key={uploadFieldKey}
        name="imageUrl"
        category="luckybag"
        className="md:col-span-2"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        판매중
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          복주머니 상품이 추가되었습니다. 아래 보상풀(확률테이블)에서 보상 항목을 등록하세요.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "복주머니 상품 추가"}
        </button>
      </div>
    </form>
  );
}
