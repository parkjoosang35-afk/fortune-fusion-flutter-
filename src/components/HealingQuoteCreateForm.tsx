"use client";

// "힐링 문구" 관리자 콘텐츠 등록 폼.
// LuckyNumberCreateForm.tsx 구조를 참고하되, 미디어 업로드 필드는 필요 없고
// 문구 본문(content)/출처(author)/분류(category) 텍스트 입력만 사용한다.
import { useActionState, useRef } from "react";
import { createHealingQuote, type HealingQuoteFormState } from "@/app/actions/healingQuote";

const initialState: HealingQuoteFormState = {};

export default function HealingQuoteCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createHealingQuote, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">새 힐링 문구 추가</h3>

      <div className="col-span-full">
        <textarea
          name="content"
          rows={3}
          required
          placeholder="좋은 글귀 / 힐링 문구 / 긍정 명언 / 응원의 한마디를 입력하세요."
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
        />
      </div>

      <input
        type="text"
        name="author"
        placeholder="출처/저자(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500 md:col-span-2"
      />
      <select
        name="category"
        defaultValue="healing"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
      >
        <option value="healing">힐링 문구</option>
        <option value="quote">좋은 글귀</option>
        <option value="encouragement">응원의 한마디</option>
        <option value="wisdom">긍정 명언</option>
      </select>
      <input
        type="number"
        name="sortOrder"
        placeholder="노출 순서"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
      />

      <label className="flex flex-col gap-1 text-xs text-slate-500">
        시작일시(선택)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        종료일시(선택)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isActive" defaultChecked className="accent-purple-500" />
        활성화(노출)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          힐링 문구가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-purple-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "힐링 문구 추가"}
        </button>
      </div>
    </form>
  );
}
