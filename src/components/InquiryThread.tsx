"use client";

// [관리자 2.0 전면 재설계 - Task 9d] 1:1 고객문의 상세 — 대화 스레드 + 답변 입력 +
// 종료/재오픈 액션.
//
// [05§1 원칙7] 종료/재오픈은 "위험 조작" 목록(환불/재발급/계정정지/역할변경)에
// 명시적으로 포함되지 않으며, 데이터 삭제나 금전적 영향이 없는 가역적 상태
// 전이이므로 ConfirmDangerDialog의 2단계 확인을 적용하지 않는다(ReportRow의
// "경고 조치"/"반려"와 동일한 수준 — 단순 버튼 1클릭 처리).
import { useActionState, useRef, useEffect } from "react";
import { sendInquiryReply, closeInquiry, reopenInquiry, type InquiryFormState } from "@/app/actions/inquiries";

interface Message {
  id: number;
  senderType: string; // user/admin
  senderAdminName: string | null;
  body: string;
  createdAt: Date;
}

interface InquiryThreadProps {
  inquiry: {
    id: number;
    status: string; // open/in_progress/closed
  };
  messages: Message[];
  canWrite: boolean;
}

const initialState: InquiryFormState = {};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function InquiryThread({ inquiry, messages, canWrite }: InquiryThreadProps) {
  const [replyState, replyAction, replyPending] = useActionState(sendInquiryReply, initialState);
  const [closeState, closeFormAction, closePending] = useActionState(closeInquiry, initialState);
  const [reopenState, reopenFormAction, reopenPending] = useActionState(reopenInquiry, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (replyState.success) {
      formRef.current?.reset();
    }
  }, [replyState.success]);

  const isClosed = inquiry.status === "closed";

  return (
    <div>
      <div className="mb-4 space-y-3 rounded-xl border border-slate-200 bg-white p-4">
        {messages.length === 0 && (
          <p className="py-6 text-center text-sm text-slate-500">아직 메시지가 없습니다.</p>
        )}
        {messages.map((m) => (
          <div
            key={m.id}
            className={`flex ${m.senderType === "admin" ? "justify-end" : "justify-start"}`}
          >
            <div
              className={`max-w-[70%] rounded-xl px-3 py-2 text-sm ${
                m.senderType === "admin"
                  ? "bg-indigo-600 text-white"
                  : "bg-slate-100 text-slate-800"
              }`}
            >
              <div className="mb-1 text-[10px] opacity-70">
                {m.senderType === "admin" ? `운영자${m.senderAdminName ? ` · ${m.senderAdminName}` : ""}` : "회원"}
                {" · "}
                {fmtDate(m.createdAt)}
              </div>
              <div className="whitespace-pre-wrap">{m.body}</div>
            </div>
          </div>
        ))}
      </div>

      {canWrite && (
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          {isClosed ? (
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm text-slate-500">
                종료된 문의입니다. 답변하려면 먼저 재오픈하세요.
              </p>
              <form action={reopenFormAction}>
                <input type="hidden" name="id" value={inquiry.id} />
                <button
                  type="submit"
                  disabled={reopenPending}
                  className="rounded-lg border border-indigo-300 px-3 py-1.5 text-xs font-medium text-indigo-700 hover:bg-indigo-100 disabled:opacity-50"
                >
                  {reopenPending ? "처리 중..." : "재오픈"}
                </button>
              </form>
            </div>
          ) : (
            <div className="space-y-2">
              <form ref={formRef} action={replyAction} className="space-y-2">
                <input type="hidden" name="id" value={inquiry.id} />
                <textarea
                  name="body"
                  rows={3}
                  required
                  placeholder="답변 내용을 입력하세요..."
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-400 focus:outline-none"
                />
                <button
                  type="submit"
                  disabled={replyPending}
                  className="rounded-lg bg-indigo-600 px-4 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
                >
                  {replyPending ? "전송 중..." : "답변 전송"}
                </button>
              </form>
              <form action={closeFormAction} className="flex justify-end">
                <input type="hidden" name="id" value={inquiry.id} />
                <button
                  type="submit"
                  disabled={closePending}
                  className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
                >
                  {closePending ? "처리 중..." : "종료 처리"}
                </button>
              </form>
            </div>
          )}
          {replyState.error && <p className="mt-2 text-xs text-red-700">{replyState.error}</p>}
          {closeState.error && <p className="mt-2 text-xs text-red-700">{closeState.error}</p>}
          {reopenState.error && <p className="mt-2 text-xs text-red-700">{reopenState.error}</p>}
        </div>
      )}
    </div>
  );
}
