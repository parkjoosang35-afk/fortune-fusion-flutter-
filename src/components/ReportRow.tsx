"use client";

import { useActionState } from "react";
import { assignReportToMe, actionReport, rejectReport, type ReportFormState } from "@/app/actions/reports";

interface ReportRowProps {
  report: {
    id: number;
    targetType: string; // post/comment/wish/user
    targetLabel: string; // 대상 라벨(애플리케이션 레벨 조합)
    reporterNickname: string;
    reason: string;
    assignedAdminName: string | null;
    action: string | null;
    status: string; // pending/reviewed/actioned/rejected
    createdAt: Date;
  };
  canWrite: boolean;
}

const initialState: ReportFormState = {};

const TARGET_TYPE_LABEL: Record<string, string> = {
  post: "게시글",
  comment: "댓글",
  wish: "소원",
  user: "회원",
};

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  pending: { label: "접수", cls: "bg-slate-800 text-slate-300" },
  reviewed: { label: "검토중", cls: "bg-amber-950/60 text-amber-400" },
  actioned: { label: "조치완료", cls: "bg-emerald-950/60 text-emerald-400" },
  rejected: { label: "반려", cls: "bg-rose-950/60 text-rose-400" },
};

const ACTION_LABEL: Record<string, string> = {
  deleted: "삭제",
  suspended: "계정정지",
  warned: "경고",
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function ReportRow({ report, canWrite }: ReportRowProps) {
  const [assignState, assignAction, assignPending] = useActionState(assignReportToMe, initialState);
  const [actionState, actionFormAction, actionPending] = useActionState(actionReport, initialState);
  const [rejectState, rejectAction, rejectPending] = useActionState(rejectReport, initialState);

  const st = STATUS_LABEL[report.status] ?? { label: report.status, cls: "bg-slate-800 text-slate-400" };
  const isOpen = report.status === "pending" || report.status === "reviewed";
  const canDeleteAction = report.targetType !== "user"; // 회원 신고는 "삭제" 조치 불가(actions/reports.ts와 동일 제약)

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40 align-top">
      <td className="px-4 py-3 text-slate-400">
        <span className="mr-1 rounded bg-slate-800 px-1.5 py-0.5 text-[10px] text-slate-400">
          {TARGET_TYPE_LABEL[report.targetType] ?? report.targetType}
        </span>
        {report.targetLabel}
      </td>
      <td className="px-4 py-3 text-slate-200">{report.reason}</td>
      <td className="px-4 py-3 text-slate-400">{report.reporterNickname}</td>
      <td className="px-4 py-3 text-slate-400">
        {report.assignedAdminName ?? <span className="text-slate-600">미배정</span>}
        {report.action && (
          <div className="mt-1 text-[10px] text-slate-500">조치: {ACTION_LABEL[report.action] ?? report.action}</div>
        )}
      </td>
      <td className="px-4 py-3">
        <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
      </td>
      <td className="px-4 py-3 text-slate-500">{fmtDate(report.createdAt)}</td>
      <td className="px-4 py-3">
        {canWrite && isOpen ? (
          <div className="flex flex-wrap gap-2">
            {report.status === "pending" && (
              <form action={assignAction}>
                <input type="hidden" name="id" value={report.id} />
                <button
                  type="submit"
                  disabled={assignPending}
                  className="rounded-lg border border-indigo-900 px-3 py-1 text-xs text-indigo-400 hover:bg-indigo-950/40 disabled:opacity-50"
                >
                  담당자 배정(나)
                </button>
              </form>
            )}
            {report.status === "reviewed" && (
              <>
                {canDeleteAction && (
                  <form action={actionFormAction}>
                    <input type="hidden" name="id" value={report.id} />
                    <input type="hidden" name="action" value="deleted" />
                    <button
                      type="submit"
                      disabled={actionPending}
                      className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
                    >
                      삭제 조치
                    </button>
                  </form>
                )}
                <form action={actionFormAction}>
                  <input type="hidden" name="id" value={report.id} />
                  <input type="hidden" name="action" value="warned" />
                  <button
                    type="submit"
                    disabled={actionPending}
                    className="rounded-lg border border-amber-900 px-3 py-1 text-xs text-amber-400 hover:bg-amber-950/40 disabled:opacity-50"
                  >
                    경고 조치
                  </button>
                </form>
                <form action={actionFormAction}>
                  <input type="hidden" name="id" value={report.id} />
                  <input type="hidden" name="action" value="suspended" />
                  <button
                    type="submit"
                    disabled={actionPending}
                    className="rounded-lg border border-orange-900 px-3 py-1 text-xs text-orange-400 hover:bg-orange-950/40 disabled:opacity-50"
                  >
                    계정정지
                  </button>
                </form>
                <form action={rejectAction}>
                  <input type="hidden" name="id" value={report.id} />
                  <button
                    type="submit"
                    disabled={rejectPending}
                    className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-400 hover:bg-slate-800 disabled:opacity-50"
                  >
                    반려
                  </button>
                </form>
              </>
            )}
          </div>
        ) : (
          <span className="text-xs text-slate-600">처리 완료</span>
        )}
        {assignState.error && <p className="mt-1 text-xs text-red-400">{assignState.error}</p>}
        {actionState.error && <p className="mt-1 text-xs text-red-400">{actionState.error}</p>}
        {rejectState.error && <p className="mt-1 text-xs text-red-400">{rejectState.error}</p>}
      </td>
    </tr>
  );
}
