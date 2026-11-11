"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { deletePremiumSajuSection, type PremiumSajuFormState } from "@/app/actions/premium-saju";

const initialState: PremiumSajuFormState = {};

export default function DeletePremiumSajuSectionButton({ sectionKey }: { sectionKey: string }) {
  const [state, formAction, pending] = useActionState(deletePremiumSajuSection, initialState);
  const router = useRouter();

  if (state.success) {
    router.push("/ai-content/premium-saju");
  }

  return (
    <form
      action={formAction}
      onSubmit={(e) => {
        if (!confirm("이 섹션의 모든 버전을 삭제하시겠습니까?")) {
          e.preventDefault();
        }
      }}
    >
      <input type="hidden" name="sectionKey" value={sectionKey} />
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg border border-red-300 px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-100 disabled:opacity-50"
      >
        {pending ? "삭제 중..." : "섹션 삭제"}
      </button>
      {state.error && <p className="mt-1 text-xs text-red-700">{state.error}</p>}
    </form>
  );
}
