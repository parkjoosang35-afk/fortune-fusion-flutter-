"use client";

import { useActionState, useRef } from "react";
import { createLuckybagRewardPool, type LuckybagFormState } from "@/app/actions/luckybag";

interface LuckybagRewardPoolCreateFormProps {
  canWrite: boolean;
  products: { id: number; name: string }[];
  grades: { id: number; name: string; code: string }[];
}

const REWARD_TYPES = [
  { value: "none", label: "꽝(보상 없음)" },
  { value: "point", label: "포인트" },
  { value: "amulet", label: "부적" },
  { value: "giftcard_fragment", label: "상품권 조각" },
];

const initialState: LuckybagFormState = {};

export default function LuckybagRewardPoolCreateForm({
  canWrite,
  products,
  grades,
}: LuckybagRewardPoolCreateFormProps) {
  const [state, formAction, pending] = useActionState(createLuckybagRewardPool, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-6"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">
        새 보상 항목 추가 (확률테이블)
      </h3>
      <select
        name="luckybagProductId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      >
        <option value="" disabled>
          복주머니 상품 선택
        </option>
        {products.map((p) => (
          <option key={p.id} value={p.id}>
            {p.name}
          </option>
        ))}
      </select>
      <select
        name="gradeId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="" disabled>
          등급 선택
        </option>
        {grades.map((g) => (
          <option key={g.id} value={g.id}>
            {g.name} ({g.code})
          </option>
        ))}
      </select>
      <select
        name="rewardType"
        required
        defaultValue="point"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        {REWARD_TYPES.map((rt) => (
          <option key={rt.value} value={rt.value}>
            {rt.label}
          </option>
        ))}
      </select>
      <input
        type="number"
        name="rewardAmount"
        placeholder="보상 수량/금액 (선택)"
        min={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="probability"
        placeholder="확률(%)"
        min={0.0001}
        max={100}
        step={0.0001}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          보상 항목이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "보상 항목 추가"}
        </button>
        <p className="mt-2 text-xs text-slate-500">
          ※ 04A I-3 명시: 동일 상품 내 보상 항목의 확률 합계는 100%를 넘을 수 없습니다.
          위 상품 목록의 &quot;확률 합계&quot; 뱃지가 100%가 아니면 아직 확률테이블이 미완성 상태입니다.
        </p>
      </div>
    </form>
  );
}
