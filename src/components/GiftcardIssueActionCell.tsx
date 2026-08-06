"use client";

// 05_Admin_System_Design.md §3.4 "상품권 환불/재발급 처리" — 2단계 확인 필수.
// [설계 결정] 코드베이스에 기존 재사용 가능한 "2단계 확인" UI 패턴이 없어 신규 설계.
//   기존 GiftcardProductRow.tsx의 editing(boolean) 토글 컨벤션을 확장하여,
//   1단계: "환불 처리"/"재발급 처리" 버튼 클릭 → 사유 입력 + 확인 패널 노출
//   2단계: 확인 패널에서 "정말 처리하시겠습니까?" 재확인 후 최종 "확인" 클릭 시에만
//          실제 Server Action(form submit)이 실행된다. 중간에 "취소"로 언제든 되돌릴 수 있다.
import { useActionState, useState } from "react";
import {
  refundGiftcardIssue,
  reissueGiftcardIssue,
  type GiftcardLifecycleFormState,
} from "@/app/actions/giftcard-lifecycle";

type Mode = "idle" | "refund-step1" | "refund-step2" | "reissue-step1" | "reissue-step2";

const initialState: GiftcardLifecycleFormState = {};

interface GiftcardIssueActionCellProps {
  issueId: number;
  pointSpent: number;
  canWrite: boolean;
  eligible: boolean; // status === "issued" && 미사용
}

export default function GiftcardIssueActionCell({
  issueId,
  pointSpent,
  canWrite,
  eligible,
}: GiftcardIssueActionCellProps) {
  const [mode, setMode] = useState<Mode>("idle");
  const [reason, setReason] = useState("");
  const [refundState, refundAction, refundPending] = useActionState(
    refundGiftcardIssue,
    initialState
  );
  const [reissueState, reissueAction, reissuePending] = useActionState(
    reissueGiftcardIssue,
    initialState
  );

  if (!canWrite) {
    return <span className="text-xs text-slate-500">권한 없음</span>;
  }
  if (!eligible) {
    return <span className="text-xs text-slate-500">-</span>;
  }

  const reset = () => {
    setMode("idle");
    setReason("");
  };

  if (mode === "idle") {
    return (
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setMode("refund-step1")}
          className="rounded-lg border border-amber-300 px-2 py-1 text-xs text-amber-700 hover:bg-amber-100"
        >
          환불 처리
        </button>
        <button
          type="button"
          onClick={() => setMode("reissue-step1")}
          className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-100"
        >
          재발급 처리
        </button>
      </div>
    );
  }

  // ── 1단계: 사유 입력 ──
  if (mode === "refund-step1" || mode === "reissue-step1") {
    const isRefund = mode === "refund-step1";
    return (
      <div className="min-w-[220px] space-y-1.5 rounded-lg border border-slate-300 bg-white/60 p-2">
        <p className="text-xs font-medium text-slate-600">
          {isRefund ? "환불 사유" : "재발급 사유"} (필수)
        </p>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          rows={2}
          placeholder={isRefund ? "예: 회원 요청에 의한 환불" : "예: 코드 유실로 인한 재발급"}
          className="w-full rounded-lg border border-slate-300 bg-white px-2 py-1 text-xs text-slate-900 outline-none focus:border-indigo-500"
        />
        <div className="flex gap-2">
          <button
            type="button"
            disabled={!reason.trim()}
            onClick={() => setMode(isRefund ? "refund-step2" : "reissue-step2")}
            className="rounded-lg bg-indigo-600 px-2 py-1 text-xs font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            다음
          </button>
          <button
            type="button"
            onClick={reset}
            className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-100"
          >
            취소
          </button>
        </div>
      </div>
    );
  }

  // ── 2단계: 최종 확인 ──
  const isRefund = mode === "refund-step2";
  const state = isRefund ? refundState : reissueState;
  const pending = isRefund ? refundPending : reissuePending;
  const action = isRefund ? refundAction : reissueAction;

  return (
    <div className="min-w-[240px] space-y-1.5 rounded-lg border border-rose-300/60 bg-rose-100 p-2">
      <p className="text-xs font-semibold text-rose-800">
        {isRefund
          ? `정말 환불 처리하시겠습니까? (${pointSpent.toLocaleString()}P 자동 복원)`
          : "정말 재발급 처리하시겠습니까? (새 코드 발급)"}
      </p>
      <p className="text-xs text-slate-500">사유: {reason}</p>
      <form action={action} className="flex gap-2">
        <input type="hidden" name="issueId" value={issueId} />
        <input type="hidden" name="reason" value={reason} />
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-rose-700 px-2 py-1 text-xs font-medium text-white hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "처리 중..." : "확인(최종 처리)"}
        </button>
        <button
          type="button"
          onClick={reset}
          className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-100"
        >
          취소
        </button>
      </form>
      {state.error && <p className="text-xs text-red-700">{state.error}</p>}
      {state.success && <p className="text-xs text-emerald-700">처리가 완료되었습니다.</p>}
    </div>
  );
}
