"use client";

import { useActionState, useRef } from "react";
import { createBoard, type CommunityFormState } from "@/app/actions/community";

interface CommunityBoardCreateFormProps {
  canWrite: boolean;
}

const initialState: CommunityFormState = {};

export default function CommunityBoardCreateForm({ canWrite }: CommunityBoardCreateFormProps) {
  const [state, formAction, pending] = useActionState(createBoard, initialState);
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
      <h3 className="col-span-full text-sm font-semibold text-white">새 게시판 추가</h3>
      <input
        type="text"
        name="code"
        placeholder="게시판 코드 (예: free)"
        required
        maxLength={30}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="name"
        placeholder="게시판 이름 (예: 자유게시판)"
        required
        maxLength={50}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="description"
        placeholder="설명 (선택)"
        maxLength={200}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="number"
        name="sortOrder"
        placeholder="정렬 순서"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isPublic" defaultChecked className="h-4 w-4" />
        공개 게시판
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          게시판이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "게시판 추가"}
        </button>
      </div>
    </form>
  );
}
