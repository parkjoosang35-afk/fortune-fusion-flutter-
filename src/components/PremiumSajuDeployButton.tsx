"use client";

// [관리자 2.0 전면 재설계 - Task 12b] 프리미엄사주 섹션 — 버전 배포(is_active 토글) 버튼.
// PromptDeployButton.tsx와 완전히 동일한 패턴.
import { useActionState } from "react";
import {
  deployPremiumSajuVersion,
  type PremiumSajuFormState,
} from "@/app/actions/premium-saju";

const initialState: PremiumSajuFormState = {};

interface PremiumSajuDeployButtonProps {
  sectionKey: string;
  templateId: number;
  isActive: boolean;
  canWrite: boolean;
}

export default function PremiumSajuDeployButton({
  sectionKey,
  templateId,
  isActive,
  canWrite,
}: PremiumSajuDeployButtonProps) {
  const [state, formAction, pending] = useActionState(deployPremiumSajuVersion, initialState);

  if (!canWrite) {
    return isActive ? (
      <span className="rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700">
        배포중
      </span>
    ) : (
      <span className="text-xs text-slate-500">-</span>
    );
  }

  if (isActive) {
    return (
      <span className="rounded-full bg-emerald-100 px-2 py-1 text-xs font-medium text-emerald-700">
        배포중
      </span>
    );
  }

  return (
    <form action={formAction}>
      <input type="hidden" name="sectionKey" value={sectionKey} />
      <input type="hidden" name="templateId" value={templateId} />
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg border border-indigo-500/60 px-2 py-1 text-xs font-medium text-indigo-700 transition hover:bg-indigo-100 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {pending ? "배포 중..." : "이 버전 배포"}
      </button>
      {state.error && <p className="mt-1 text-xs text-red-700">{state.error}</p>}
    </form>
  );
}
