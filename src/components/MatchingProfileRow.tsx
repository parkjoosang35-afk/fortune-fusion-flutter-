"use client";

import { useActionState } from "react";
import { setMatchingProfileStatus, type MatchingProfileFormState } from "@/app/actions/matching";

interface MatchingProfileRowProps {
  profile: {
    id: number;
    userNickname: string;
    isPublic: boolean;
    preferencesSummary: string; // JSON 문자열을 애플리케이션 레벨에서 요약한 표시용 문자열
    introText: string | null;
    status: string;
    createdAt: Date;
  };
  canWrite: boolean;
}

const initialState: MatchingProfileFormState = {};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  active: { label: "노출중", cls: "bg-emerald-100 text-emerald-700" },
  deactivated_by_admin: { label: "관리자 비활성화", cls: "bg-rose-100 text-rose-700" },
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function MatchingProfileRow({ profile, canWrite }: MatchingProfileRowProps) {
  const [state, formAction, pending] = useActionState(setMatchingProfileStatus, initialState);
  const st = STATUS_LABEL[profile.status] ?? { label: profile.status, cls: "bg-white text-slate-500" };

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-700">{profile.userNickname}</td>
      <td className="px-4 py-3 text-slate-600">
        {profile.isPublic ? (
          <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700">공개</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비공개</span>
        )}
      </td>
      <td className="max-w-[220px] truncate px-4 py-3 text-slate-500" title={profile.introText ?? ""}>
        {profile.introText ?? <span className="text-slate-600">-</span>}
      </td>
      <td className="max-w-[200px] truncate px-4 py-3 text-xs text-slate-500" title={profile.preferencesSummary}>
        {profile.preferencesSummary || <span className="text-slate-600">-</span>}
      </td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(profile.createdAt)}</td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && profile.status === "deactivated_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={profile.id} />
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
          {canWrite && profile.status !== "deactivated_by_admin" && (
            <form action={formAction}>
              <input type="hidden" name="id" value={profile.id} />
              <input type="hidden" name="status" value="deactivated_by_admin" />
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg border border-red-300 px-3 py-1 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50"
              >
                강제 비활성화
              </button>
            </form>
          )}
        </div>
        {state.error && <p className="mt-1 text-xs text-red-700">{state.error}</p>}
      </td>
    </tr>
  );
}
