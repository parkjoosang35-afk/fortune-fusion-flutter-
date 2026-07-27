"use client";

import { useActionState, useRef, useState } from "react";
import { createAmuletItem, type AmuletFormState } from "@/app/actions/amulets";
import ImageUploadField from "@/components/ImageUploadField";

interface AmuletItemCreateFormProps {
  canWrite: boolean;
  grades: { id: number; name: string; code: string }[];
}

const initialState: AmuletFormState = {};

export default function AmuletItemCreateForm({ canWrite, grades }: AmuletItemCreateFormProps) {
  const [state, formAction, pending] = useActionState(createAmuletItem, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  // 업로드 필드는 URL을 컨트롤드 state로 들고 있어서 form.reset()만으로는
  // 초기화되지 않는다. 제출 완료 시 key를 바꿔 강제로 리마운트해 초기화한다.
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
      <h3 className="col-span-full text-sm font-semibold text-white">새 부적 상품 추가</h3>
      <input
        type="text"
        name="name"
        placeholder="부적 이름"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
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
      <input
        type="number"
        name="pricePoint"
        placeholder="가격(포인트)"
        min={0}
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <textarea
        name="effectDescription"
        placeholder="효과 설명"
        required
        rows={2}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      <ImageUploadField
        key={uploadFieldKey}
        name="imageUrl"
        category="amulets"
        className="md:col-span-2"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isAiGenerated" className="accent-indigo-500" />
        AI 생성 이미지
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isLimited" className="accent-indigo-500" />
        한정판
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          부적 상품이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "부적 상품 추가"}
        </button>
      </div>
    </form>
  );
}
