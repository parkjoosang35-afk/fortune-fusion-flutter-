"use client";

import { useActionState } from "react";
import { setFileStatus, type FileFormState } from "@/app/actions/files";

interface FileRowProps {
  file: {
    id: number;
    ownerType: string; // user_profile/community_post/amulet_item/banner
    ownerLabel: string; // 대상 라벨(애플리케이션 레벨 조합, 미연결이면 "미연결")
    fileUrl: string;
    fileType: string; // image/video
    size: number | null;
    status: string;
    createdAt: Date;
  };
  canDelete: boolean;
}

const initialState: FileFormState = {};

const OWNER_TYPE_LABEL: Record<string, string> = {
  user_profile: "프로필",
  community_post: "게시글",
  amulet_item: "부적",
  banner: "배너",
};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  active: { label: "정상", cls: "bg-emerald-100 text-emerald-700" },
  deleted_by_admin: { label: "관리자 삭제", cls: "bg-rose-100 text-rose-700" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

function fmtSize(bytes: number | null): string {
  if (bytes === null) return "-";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function FileRow({ file, canDelete }: FileRowProps) {
  const [state, formAction, pending] = useActionState(setFileStatus, initialState);
  const st = STATUS_LABEL[file.status] ?? { label: file.status, cls: "bg-white text-slate-500" };

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-500">
        <span className="mr-1 rounded bg-white px-1.5 py-0.5 text-[10px] text-slate-500">
          {OWNER_TYPE_LABEL[file.ownerType] ?? file.ownerType}
        </span>
        {file.ownerLabel}
      </td>
      <td className="max-w-xs truncate px-4 py-3 text-slate-700">
        <a
          href={file.fileUrl}
          target="_blank"
          rel="noreferrer"
          className="hover:text-indigo-700 hover:underline"
          title={file.fileUrl}
        >
          {file.fileUrl}
        </a>
      </td>
      <td className="px-4 py-3 text-slate-500">
        <span className="rounded bg-white px-1.5 py-0.5 text-[10px] uppercase text-slate-500">
          {file.fileType}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtSize(file.size)}</td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(file.createdAt)}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canDelete && file.status === "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={file.id} />
              <input type="hidden" name="status" value="active" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-emerald-300 px-3 py-1 text-xs text-emerald-700 hover:bg-emerald-100 disabled:opacity-50"
              >
                복원
              </button>
            </form>
          )}
          {canDelete && file.status !== "deleted_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={file.id} />
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
