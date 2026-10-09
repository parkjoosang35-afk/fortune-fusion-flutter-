"use client";

// [신통방통 관리자 통합 간소화 실행 지시서 task 6] 어뷰징 의심 후기(status="review")
// 승인/반려 행. 승인=보상 지급(grantReviewReward)+visible 전환, 반려=hidden_by_report
// 전환(보상 미지급). 둘 다 05§1 원칙7(2단계 확인 대상: 환불/재발급/계정정지/역할변경)에
// 해당하지 않으므로 ReportRow.tsx의 계정정지처럼 ConfirmDangerDialog를 쓰지 않는다.
import { useActionState } from "react";
import { approveReview, rejectReview, type WishroomActionState } from "@/app/actions/wishroom-admin";

interface ReviewApprovalRowProps {
  review: {
    id: number;
    roomId: number;
    text: string;
    photoUrl: string | null;
    flags: string[];
    userNickname: string;
    roomWishText: string;
    createdAt: Date;
  };
  canWrite: boolean;
}

const initialState: WishroomActionState = {};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

function truncate(text: string, len: number): string {
  return text.length > len ? text.slice(0, len) + "…" : text;
}

export default function ReviewApprovalRow({ review, canWrite }: ReviewApprovalRowProps) {
  const [approveState, approveAction, approvePending] = useActionState(approveReview, initialState);
  const [rejectState, rejectAction, rejectPending] = useActionState(rejectReview, initialState);

  return (
    <tr className="border-b border-slate-200/60 align-top hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-500">
        #{review.roomId} {truncate(review.roomWishText, 20)}
      </td>
      <td className="px-4 py-3 text-slate-500">{review.userNickname}</td>
      <td className="px-4 py-3 text-slate-700">
        {truncate(review.text, 40)}
        {review.photoUrl && (
          <span className="ml-1 rounded bg-indigo-100 px-1.5 py-0.5 text-[10px] text-indigo-700">
            사진첨부
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-1">
          {review.flags.map((flag) => (
            <span
              key={flag}
              className="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700"
            >
              {flag}
            </span>
          ))}
        </div>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(review.createdAt)}</td>
      <td className="px-4 py-3">
        {canWrite ? (
          <div className="flex flex-wrap gap-2">
            <form action={approveAction}>
              <input type="hidden" name="id" value={review.id} />
              <button
                type="submit"
                disabled={approvePending}
                className="rounded-lg border border-emerald-300 px-3 py-1 text-xs text-emerald-700 hover:bg-emerald-100 disabled:opacity-50"
              >
                승인(보상지급)
              </button>
            </form>
            <form action={rejectAction}>
              <input type="hidden" name="id" value={review.id} />
              <button
                type="submit"
                disabled={rejectPending}
                className="rounded-lg border border-rose-300 px-3 py-1 text-xs text-rose-700 hover:bg-rose-100 disabled:opacity-50"
              >
                반려(숨김)
              </button>
            </form>
          </div>
        ) : (
          <span className="text-xs text-slate-600">읽기 전용</span>
        )}
        {approveState.error && <p className="mt-1 text-xs text-red-700">{approveState.error}</p>}
        {rejectState.error && <p className="mt-1 text-xs text-red-700">{rejectState.error}</p>}
      </td>
    </tr>
  );
}
