"use client";

import { useActionState, useRef } from "react";
import { createGiftcardProduct, type GiftcardFormState } from "@/app/actions/giftcards";

interface GiftcardProductCreateFormProps {
  canWrite: boolean;
}

const initialState: GiftcardFormState = {};

export default function GiftcardProductCreateForm({
  canWrite,
}: GiftcardProductCreateFormProps) {
  const [state, formAction, pending] = useActionState(createGiftcardProduct, initialState);
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
      <h3 className="col-span-full text-sm font-semibold text-white">새 상품권 상품 추가</h3>
      <input
        type="text"
        name="name"
        placeholder="상품명 (예: 스타벅스 아메리카노 교환권)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="brand"
        placeholder="브랜드 (예: 스타벅스)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="requiredPoint"
        placeholder="필요 포인트"
        min={0}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="stockCount"
        placeholder="재고 수량"
        min={0}
        required
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="validDays"
        placeholder="유효기간(일)"
        min={1}
        defaultValue={365}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="imageUrl"
        placeholder="이미지 URL (선택)"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
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
          상품권 상품이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "상품권 상품 추가"}
        </button>
      </div>
    </form>
  );
}
