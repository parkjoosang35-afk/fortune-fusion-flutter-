"use client";

// 버전 배포(is_active 토글) 버튼 — 05§4.3
import { useActionState } from "react";
import {
  deployPromptVersion,
  type DeployFormState,
} from "@/app/actions/ai-prompts";

const initialState: DeployFormState = {};

interface PromptDeployButtonProps {
  domain: string;
  templateId: number;
  isActive: boolean;
  canWrite: boolean;
}

export default function PromptDeployButton({
  domain,
  templateId,
  isActive,
  canWrite,
}: PromptDeployButtonProps) {
  const [state, formAction, pending] = useActionState(
    deployPromptVersion,
    initialState
  );

  if (!canWrite) {
    return isActive ? (
      <span className="rounded-full bg-emerald-950/60 px-2 py-1 text-xs font-medium text-emerald-400">
        배포중
      </span>
    ) : (
      <span className="text-xs text-slate-500">-</span>
    );
  }

  if (isActive) {
    return (
      <span className="rounded-full bg-emerald-950/60 px-2 py-1 text-xs font-medium text-emerald-400">
        배포중
      </span>
    );
  }

  return (
    <form action={formAction}>
      <input type="hidden" name="domain" value={domain} />
      <input type="hidden" name="templateId" value={templateId} />
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg border border-indigo-500/60 px-2 py-1 text-xs font-medium text-indigo-400 transition hover:bg-indigo-950/60 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? "배포 중..." : "이 버전 배포"}
      </button>
      {state.error && (
        <p className="mt-1 text-xs text-red-400">{state.error}</p>
      )}
    </form>
  );
}
