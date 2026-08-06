"use client";

import { useActionState, useRef, useState } from "react";
import { createPopup, type PopupFormState } from "@/app/actions/popups";
import ImageUploadField from "@/components/ImageUploadField";

const initialState: PopupFormState = {};

export default function PopupCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createPopup, initialState);
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
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">새 팝업 추가</h3>
      <input
        type="text"
        name="title"
        placeholder="팝업 제목 (예: 신규 가입 이벤트 안내)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="segment"
        placeholder="대상 세그먼트 (선택, 예: new_user)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <ImageUploadField
        key={uploadFieldKey}
        name="imageUrl"
        category="popups"
        className="md:col-span-2"
        placeholder="이미지 URL (선택 - 텍스트 전용 팝업 허용)"
      />
      <input
        type="text"
        name="linkUrl"
        placeholder="연결 링크 URL (선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        노출 시작일시(필수)
        <input
          type="datetime-local"
          name="startAt"
          required
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        노출 종료일시(필수)
        <input
          type="datetime-local"
          name="endAt"
          required
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="once" className="accent-indigo-500" />
        1회성 노출(사용자당 1회만 표시)
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화(노출)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          팝업이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "팝업 추가"}
        </button>
      </div>
    </form>
  );
}
