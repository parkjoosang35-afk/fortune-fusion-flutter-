"use client";

// 05§1 설계원칙 7번: 위험 조작(환불/재발급/계정정지/역할변경)은 2단계 확인 필수.
// "계정정지" 조치는 신고글의 reason 필드에 사유가 이미 존재하므로 별도 사유 입력 없이
// confirm 단계만 추가한다(LuckybagRewardPoolRow.tsx와 동일 패턴). 경고/삭제조치/반려는
// 원칙7 대상 목록에 없으므로 이번 수정 범위에서 제외한다.
import { useActionState, useState } from "react";
import { assignReportToMe, actionReport, rejectReport, type ReportFormState } from "@/app/actions/reports";

interface ReportRowProps {
  report: {
    id: number;
    targetType: string; // post/comment/wish/user/fortune_result
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
  fortune_result: "운세결과",
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
  const [confirmingSuspend, setConfirmingSuspend] = useState(false);

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
                <form
                  onSubmit={(e) => {
                    // 05§1 원칙7: 1단계 제출 시점에는 서버 전송을 막고 2단계 확인만 노출한다.
                    if (!confirmingSuspend) {
                      e.preventDefault();
                      setConfirmingSuspend(true);
                    }
                  }}
                  action={actionFormAction}
                  className="flex flex-col items-start gap-1"
                >
                  <input type="hidden" name="id" value={report.id} />
                  <input type="hidden" name="action" value="suspended" />
                  {confirmingSuspend && (
                    <p className="max-w-[220px] rounded-lg border border-rose-900/60 bg-rose-950/20 p-2 text-[11px] font-semibold text-rose-300">
                      ⚠ 정말 계정정지 조치하시겠습니까? (다시 누르면 처리됩니다)
                    </p>
                  )}
                  <div className="flex gap-1">
                    <button
                      type="submit"
                      disabled={actionPending}
                      className={
                        confirmingSuspend
                          ? "rounded-lg bg-rose-700 px-3 py-1 text-xs font-medium text-white hover:bg-rose-600 disabled:opacity-50"
                          : "rounded-lg border border-orange-900 px-3 py-1 text-xs text-orange-400 hover:bg-orange-950/40 disabled:opacity-50"
                      }
                    >
                      {actionPending ? "처리 중..." : confirmingSuspend ? "확인(최종 처리)" : "계정정지"}
                    </button>
                    {confirmingSuspend && (
                      <button
                        type="button"
                        onClick={() => setConfirmingSuspend(false)}
                        className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
                      >
                        취소
                      </button>
                    )}
                  </div>
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
