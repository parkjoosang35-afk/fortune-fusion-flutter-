"use client";

import { useActionState } from "react";
import { setCommentStatus, type CommentFormState } from "@/app/actions/comments";

interface CommentRowProps {
  comment: {
    id: number;
    targetType: string; // post/wish
    targetLabel: string; // 대상 게시글 제목 또는 소원 내용 요약(애플리케이션 레벨 조합)
    userNickname: string;
    content: string;
    status: string;
    createdAt: Date;
  };
  canDelete: boolean;
}

const initialState: CommentFormState = {};

const TARGET_TYPE_LABEL: Record<string, string> = {
  post: "게시글",
  wish: "소원",
};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  active: { label: "노출중", cls: "bg-emerald-950/60 text-emerald-400" },
  deleted_by_admin: { label: "관리자 삭제", cls: "bg-rose-950/60 text-rose-400" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function CommentRow({ comment, canDelete }: CommentRowProps) {
  const [state, formAction, pending] = useActionState(setCommentStatus, initialState);
  const st = STATUS_LABEL[comment.status] ?? { label: comment.status, cls: "bg-slate-800 text-slate-400" };

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-400">
        <span className="mr-1 rounded bg-slate-800 px-1.5 py-0.5 text-[10px] text-slate-400">
          {TARGET_TYPE_LABEL[comment.targetType] ?? comment.targetType}
        </span>
        {comment.targetLabel}
      </td>
      <td className="px-4 py-3 text-slate-200">{comment.content}</td>
      <td className="px-4 py-3 text-slate-400">{comment.userNickname}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(comment.createdAt)}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canDelete && comment.status === "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={comment.id} />
              <input type="hidden" name="status" value="active" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-emerald-900 px-3 py-1 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
              >
                복원
              </button>
            </form>
          )}
          {canDelete && comment.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={comment.id} />
              <input type="hidden" name="status" value="deleted_by_admin" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {state.error && <p className="mt-1 text-xs text-red-400">{state.error}</p>}
      </td>
    </tr>
  );
}
