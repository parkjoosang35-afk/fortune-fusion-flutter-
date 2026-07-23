"use client";

import { useActionState, useState } from "react";
import {
  changeUserStatus,
  type StatusChangeFormState,
} from "@/app/actions/users";

const initialState: StatusChangeFormState = {};

interface UserStatusChangeFormProps {
  userId: number;
  currentStatus: string;
  canWrite: boolean;
}

const STATUS_OPTIONS = [
  { value: "active", label: "정상" },
  { value: "suspended", label: "정지" },
  { value: "withdrawn", label: "탈퇴" },
];

export default function UserStatusChangeForm({
  userId,
  currentStatus,
  canWrite,
}: UserStatusChangeFormProps) {
  const [state, formAction, pending] = useActionState(
    changeUserStatus,
    initialState
  );
  const [newStatus, setNewStatus] = useState(currentStatus);

  if (!canWrite) {
    return (
      <p className="text-sm text-slate-500">
        회원 상태를 변경할 권한이 없습니다.
      </p>
    );
  }

  const needsReason = newStatus === "suspended" || newStatus === "withdrawn";

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="userId" value={userId} />

      <div>
        <label className="mb-1 block text-sm font-medium text-slate-300">
          변경할 상태
        </label>
        <select
          name="newStatus"
          value={newStatus}
          onChange={(e) => setNewStatus(e.target.value)}
          className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          {STATUS_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
      </div>

      {needsReason && (
        <div>
          <label className="mb-1 block text-sm font-medium text-slate-300">
            사유 {needsReason ? "(필수)" : ""}
          </label>
          <textarea
            name="reason"
            required={needsReason}
            rows={3}
            placeholder={
              newStatus === "suspended"
                ? "정지 사유를 입력해주세요."
                : "탈퇴 사유를 입력해주세요."
            }
            className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          />
        </div>
      )}

      {state.error && (
        <p className="rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          상태가 변경되었습니다.
        </p>
      )}

      <button
        type="submit"
        disabled={pending || newStatus === currentStatus}
        className="w-full rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? "처리 중..." : "상태 변경 적용"}
      </button>
    </form>
  );
}
