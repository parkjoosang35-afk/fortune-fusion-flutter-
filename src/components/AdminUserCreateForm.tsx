"use client";

import { useActionState, useRef } from "react";
import { createAdminUser, type AdminUserFormState } from "@/app/actions/admin-users";

const initialState: AdminUserFormState = {};

interface Role {
  id: number;
  code: string;
  name: string;
}

export default function AdminUserCreateForm({
  roles,
  canWrite,
}: {
  roles: Role[];
  canWrite: boolean;
}) {
  const [state, formAction, pending] = useActionState(createAdminUser, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-2"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">새 관리자 계정 추가</h3>
      <input
        type="text"
        name="email"
        placeholder="이메일(로그인 ID)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="name"
        placeholder="이름"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="password"
        name="password"
        placeholder="초기 비밀번호(8자 이상)"
        required
        minLength={8}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <select
        name="roleId"
        required
        defaultValue=""
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        <option value="" disabled>
          역할 선택
        </option>
        {roles.map((r) => (
          <option key={r.id} value={r.id}>
            {r.name} ({r.code})
          </option>
        ))}
      </select>
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300 md:col-span-2">
        <input type="checkbox" name="is2faEnabled" className="accent-indigo-500" />
        2단계 인증(2FA) 사용
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          관리자 계정이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "계정 추가"}
        </button>
      </div>
    </form>
  );
}
