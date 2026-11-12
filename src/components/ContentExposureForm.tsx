"use client";

// [기획_01 탭④ 노출제어] 콘텐츠 1개의 exposureStatus(visible/hidden/maintenance)를
// 전환하는 폼. "점검중" 상태가 이번에 신규로 추가된 핵심 기능 — 지금까지는
// 코드 배포로만 콘텐츠를 끌 수 있었던 것을 관리자가 직접 전환할 수 있게 한다.
import { useActionState, useState } from "react";
import { updateContentExposure, type ContentOpsFormState } from "@/app/actions/content-ops";

const initialState: ContentOpsFormState = {};

interface Props {
  contentKey: string;
  currentStatus: string;
  currentNote: string | null;
  canWrite: boolean;
}

const STATUS_OPTIONS: { value: string; label: string; hint: string }[] = [
  { value: "visible", label: "노출", hint: "정상적으로 앱에 노출됩니다." },
  { value: "hidden", label: "숨김", hint: "앱 화면에서 완전히 숨겨집니다(안내문 없음)." },
  { value: "maintenance", label: "점검중", hint: "앱에 점검 안내문을 표시합니다." },
];

export default function ContentExposureForm({
  contentKey,
  currentStatus,
  currentNote,
  canWrite,
}: Props) {
  const [state, formAction, pending] = useActionState(updateContentExposure, initialState);
  const [status, setStatus] = useState(currentStatus);
  const [note, setNote] = useState(currentNote ?? "");

  if (!canWrite) {
    const opt = STATUS_OPTIONS.find((o) => o.value === currentStatus);
    return (
      <div className="rounded-lg border border-slate-200 bg-white p-4">
        <p className="text-sm text-slate-500">현재 상태</p>
        <p className="mt-1 text-lg font-semibold text-slate-900">{opt?.label ?? currentStatus}</p>
        {currentStatus === "maintenance" && currentNote && (
          <p className="mt-2 text-sm text-amber-700">안내문: {currentNote}</p>
        )}
      </div>
    );
  }

  return (
    <form action={formAction} className="space-y-3 rounded-lg border border-slate-200 bg-white p-4">
      <input type="hidden" name="contentKey" value={contentKey} />
      <p className="text-sm font-medium text-slate-900">앱 내 노출 상태</p>
      <div className="flex flex-col gap-2">
        {STATUS_OPTIONS.map((opt) => (
          <label key={opt.value} className="flex items-start gap-2 text-sm">
            <input
              type="radio"
              name="exposureStatus"
              value={opt.value}
              checked={status === opt.value}
              onChange={() => setStatus(opt.value)}
              className="mt-0.5"
            />
            <span>
              <span className="font-medium text-slate-900">{opt.label}</span>
              <span className="ml-2 text-xs text-slate-500">{opt.hint}</span>
            </span>
          </label>
        ))}
      </div>

      {status === "maintenance" && (
        <div>
          <label className="mb-1 block text-xs text-slate-500">점검 안내문(앱에 표시됨)</label>
          <textarea
            name="maintenanceNote"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={2}
            placeholder="예) 일시적으로 점검 중입니다. 빠른 시간 내 정상화하겠습니다."
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
        </div>
      )}

      {status !== "maintenance" && <input type="hidden" name="maintenanceNote" value="" />}

      <div className="flex items-center gap-2">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "저장 중..." : "저장"}
        </button>
        {state.success && <span className="text-xs text-emerald-700">저장되었습니다.</span>}
        {state.error && <span className="text-xs text-red-700">{state.error}</span>}
      </div>

      <p className="text-xs text-slate-500">
        ⚠️ 점검중 전환 시 이미 결제(복주머니 차감)된 건에 대한 자동 환불은 제공되지 않습니다.
        환불이 필요하면 포인트조정 화면에서 수동으로 처리해주세요.
      </p>
    </form>
  );
}
