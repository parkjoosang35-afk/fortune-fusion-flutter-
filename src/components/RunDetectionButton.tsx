"use client";

// [관리자 2.0 전면 재설계 - Task 11] 1단계 "탐지" 수동 실행 버튼(배치 스케줄러가
// 없는 환경이라 운영자가 버튼으로 트리거 — 보고서⑧ 확인 사실: crontab 전무).
import { useActionState } from "react";
import { runDetection, type DiagnosisFormState } from "@/app/actions/system-diagnosis";

const initialState: DiagnosisFormState = {};

export default function RunDetectionButton() {
  const [state, formAction, pending] = useActionState(runDetection, initialState);
  return (
    <div>
      <form action={formAction}>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {pending ? "탐지 중..." : "① 이상 징후 탐지 실행"}
        </button>
      </form>
      {state.error && <p className="mt-2 text-xs text-amber-700">{state.error}</p>}
      {state.success && <p className="mt-2 text-xs text-emerald-700">탐지되었습니다. 아래 목록을 확인하세요.</p>}
    </div>
  );
}
