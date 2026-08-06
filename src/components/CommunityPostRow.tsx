"use client";

import { useActionState } from "react";
import { setPostStatus, type CommunityFormState } from "@/app/actions/community";

interface CommunityPostRowProps {
  post: {
    id: number;
    boardName: string;
    userNickname: string;
    title: string;
    status: string;
    isPinned: boolean;
    likeCount: number;
    commentCount: number;
    createdAt: Date;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: CommunityFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  visible: { label: "노출중", cls: "bg-emerald-100 text-emerald-700" },
  blinded: { label: "숨김", cls: "bg-amber-100 text-amber-700" },
  deleted_by_admin: { label: "관리자 삭제", cls: "bg-rose-100 text-rose-700" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function CommunityPostRow({ post, canWrite, canDelete }: CommunityPostRowProps) {
  const [state, formAction, pending] = useActionState(setPostStatus, initialState);
  const st = STATUS_LABEL[post.status] ?? { label: post.status, cls: "bg-white text-slate-500" };

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-500">{post.boardName}</td>
      <td className="px-4 py-3 text-slate-700">
        {post.isPinned && <span className="mr-1 text-amber-700">📌</span>}
        {post.title}
      </td>
      <td className="px-4 py-3 text-slate-500">{post.userNickname}</td>
      <td className="px-4 py-3 text-slate-500">
        ❤ {post.likeCount.toLocaleString()} · 💬 {post.commentCount.toLocaleString()}
      </td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(post.createdAt)}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && post.status !== "visible" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={post.id} />
              <input type="hidden" name="status" value="visible" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-emerald-300 px-3 py-1 text-xs text-emerald-700 hover:bg-emerald-100 disabled:opacity-50"
              >
                노출
              </button>
            </form>
          )}
          {canWrite && post.status !== "blinded" && post.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={post.id} />
              <input type="hidden" name="status" value="blinded" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-amber-300 px-3 py-1 text-xs text-amber-700 hover:bg-amber-100 disabled:opacity-50"
              >
                숨김
              </button>
            </form>
          )}
          {canDelete && post.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={post.id} />
              <input type="hidden" name="status" value="deleted_by_admin" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-red-300 px-3 py-1 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {state.error && <p className="mt-1 text-xs text-red-700">{state.error}</p>}
      </td>
    </tr>
  );
}
