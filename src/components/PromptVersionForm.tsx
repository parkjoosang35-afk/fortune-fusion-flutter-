"use client";

// 새 프롬프트 버전 저장 폼 — 05§4.3 배포 워크플로우: 새 버전 저장은 항상 새 row(version+1)로 생성
import { useActionState, useState } from "react";
import {
  saveNewPromptVersion,
  type SaveVersionFormState,
} from "@/app/actions/ai-prompts";

const initialState: SaveVersionFormState = {};

interface PromptVersionFormProps {
  domain: string;
  baseTemplateBody: string;
  canWrite: boolean;
}

export default function PromptVersionForm({
  domain,
  baseTemplateBody,
  canWrite,
}: PromptVersionFormProps) {
  const [state, formAction, pending] = useActionState(
    saveNewPromptVersion,
    initialState
  );
  const [body, setBody] = useState(baseTemplateBody);

  if (!canWrite) {
    return (
      <p className="text-sm text-slate-500">
        프롬프트 템플릿을 편집할 권한이 없습니다.
      </p>
    );
  }

  return (
    <form action={formAction} className="space-y-3">
      <input type="hidden" name="domain" value={domain} />
      <div>
        <label className="mb-1 block text-sm font-medium text-slate-300">
          템플릿 내용 (수정 후 저장 시 새 버전으로 생성됩니다)
        </label>
        <textarea
          name="templateBody"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={12}
          className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 font-mono text-sm text-white outline-none focus:border-indigo-500"
        />
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
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
