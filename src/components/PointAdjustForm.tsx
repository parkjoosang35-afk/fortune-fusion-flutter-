"use client";

import { useActionState, useRef } from "react";
import { adjustUserPoint, type AdjustFormState } from "@/app/actions/point-adjust";

const initialState: AdjustFormState = {};

interface UserOption {
  id: number;
  nickname: string;
  balance: number;
}

export default function PointAdjustForm({
  canWrite,
  users,
}: {
  canWrite: boolean;
  users: UserOption[];
}) {
  const [state, formAction, pending] = useActionState(adjustUserPoint, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-5"
    >
      <h2 className="col-span-full text-sm font-semibold text-white">
        포인트 조정 (수동 지급/회수)
      </h2>
      <p className="col-span-full -mt-1 text-xs text-slate-500">
        wallets.balance 직접 수정 금지 원칙 준수 — 이 액션은 point_histories에 새 레코드를
        생성하고, 그 결과로 balance가 갱신됩니다. 사유(메모) 입력은 필수입니다.
      </p>
      <select
        name="userId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      >
        <option value="" disabled>
          회원 선택
        </option>
        {users.map((u) => (
          <option key={u.id} value={u.id}>
            {u.nickname} (현재 {u.balance.toLocaleString()}P)
          </option>
        ))}
      </select>
      <select
        name="direction"
        defaultValue="grant"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="grant">지급</option>
        <option value="revoke">회수</option>
      </select>
      <input
        type="number"
        name="amount"
        placeholder="금액"
        required
        min={1}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="memo"
        placeholder="사유 (필수)"
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
          포인트 조정이 반영되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "처리 중..." : "조정 실행"}
        </button>
      </div>
    </form>
  );
}
