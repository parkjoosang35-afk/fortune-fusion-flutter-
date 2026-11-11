"use client";

// [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 섹션 — 새 버전 저장 폼.
// PromptVersionForm.tsx와 완전히 동일한 패턴(새 버전 저장은 항상 version+1 새 row).
import { useActionState, useState } from "react";
import {
  savePremiumSajuVersion,
  type PremiumSajuFormState,
} from "@/app/actions/premium-saju";

const initialState: PremiumSajuFormState = {};

interface PremiumSajuVersionFormProps {
  sectionKey: string;
  baseTemplateBody: string;
  canWrite: boolean;
}

export default function PremiumSajuVersionForm({
  sectionKey,
  baseTemplateBody,
  canWrite,
}: PremiumSajuVersionFormProps) {
  const [state, formAction, pending] = useActionState(savePremiumSajuVersion, initialState);
  const [body, setBody] = useState(baseTemplateBody);

  if (!canWrite) {
    return <p className="text-sm text-slate-500">섹션 템플릿을 편집할 권한이 없습니다.</p>;
  }

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="sectionKey" value={sectionKey} />
      <div>
        <label className="mb-1 block text-sm font-medium text-slate-600">
          섹션 프롬프트 내용 (수정 후 저장 시 새 버전으로 생성됩니다)
        </label>
        <textarea
          name="templateBody"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={12}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 font-mono text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          새 버전으로 저장되었습니다. 목록에서 배포(활성화)를 진행해주세요.
        </p>
      )}

      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? "저장 중..." : "새 버전으로 저장"}
      </button>
    </form>
  );
}
