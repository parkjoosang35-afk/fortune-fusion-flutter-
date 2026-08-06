"use client";

import { useActionState, useRef } from "react";
import {
  createNotificationTemplate,
  type NotificationTemplateFormState,
} from "@/app/actions/notification-templates";

const initialState: NotificationTemplateFormState = {};

export default function NotificationTemplateCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createNotificationTemplate, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-2"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">새 알림 템플릿 추가</h3>
      <input
        type="text"
        name="code"
        placeholder="템플릿 코드 (예: fortune_ready)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="deepLink"
        placeholder="딥링크 URL (선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="title"
        placeholder="제목"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <textarea
        name="body"
        placeholder="본문(푸시/인앱 공용)"
        required
        rows={3}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          알림 템플릿이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "템플릿 추가"}
        </button>
      </div>
    </form>
  );
}
