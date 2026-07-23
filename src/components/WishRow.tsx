"use client";

import { useActionState } from "react";
import { setWishStatus, type CommunityFormState } from "@/app/actions/community";

interface WishRowProps {
  wish: {
    id: number;
    userNickname: string;
    content: string;
    category: string;
    isAnonymous: boolean;
    status: string;
    supportCount: number;
    createdAt: Date;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: CommunityFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  visible: { label: "노출중", cls: "bg-emerald-950/60 text-emerald-400" },
  blinded: { label: "숨김", cls: "bg-amber-950/60 text-amber-400" },
  deleted_by_admin: { label: "관리자 삭제", cls: "bg-rose-950/60 text-rose-400" },
};

const CATEGORY_LABEL: Record<string, string> = {
  health: "건강",
  wealth: "재물",
  love: "애정",
  exam: "시험",
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function WishRow({ wish, canWrite, canDelete }: WishRowProps) {
  const [state, formAction, pending] = useActionState(setWishStatus, initialState);
  const st = STATUS_LABEL[wish.status] ?? { label: wish.status, cls: "bg-slate-800 text-slate-400" };

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-400">
        {CATEGORY_LABEL[wish.category] ?? wish.category}
      </td>
      <td className="max-w-xs px-4 py-3 text-slate-200">{wish.content}</td>
      <td className="px-4 py-3 text-slate-400">{wish.isAnonymous ? "익명" : wish.userNickname}</td>
      <td className="px-4 py-3 text-slate-500">💛 {wish.supportCount.toLocaleString()}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(wish.createdAt)}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && wish.status !== "visible" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={wish.id} />
              <input type="hidden" name="status" value="visible" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-emerald-900 px-3 py-1 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
              >
                노출
              </button>
            </form>
          )}
          {canWrite && wish.status !== "blinded" && wish.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={wish.id} />
              <input type="hidden" name="status" value="blinded" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-amber-900 px-3 py-1 text-xs text-amber-400 hover:bg-amber-950/40 disabled:opacity-50"
              >
                숨김
              </button>
            </form>
          )}
          {canDelete && wish.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={wish.id} />
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
