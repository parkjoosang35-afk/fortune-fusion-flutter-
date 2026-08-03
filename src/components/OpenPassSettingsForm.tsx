"use client";

// [프리패스 단순화 - 쿠팡파트너스 전용] §1
// 관리자가 만지는 값을 "프리패스 이용시간" + "광고 확인 대기시간" 단 2개
// 드롭다운으로 줄인 싱글톤 설정 폼. 광고 이미지/쿠팡 광고 소스는 바로 아래
// 섹션(CMS 쿠팡파트너스 배너)에서 등록한다 — "하나의 관리 화면에서 운영"
// 요구사항에 따라 이 페이지 안에 함께 배치한다.
import { useActionState } from "react";
import { updateOpenPassSettings, type OpenPassSettingsFormState } from "@/app/actions/pass-policies";

const initialState: OpenPassSettingsFormState = {};

const DURATION_OPTIONS = [
  { value: 30, label: "30분" },
  { value: 60, label: "1시간" },
  { value: 120, label: "2시간" },
  { value: 180, label: "3시간" },
  { value: 1440, label: "24시간" },
];

const WAIT_SECONDS_OPTIONS = [
  { value: 4, label: "4초" },
  { value: 5, label: "5초" },
  { value: 10, label: "10초" },
];

interface OpenPassSettingsFormProps {
  canWrite: boolean;
  durationMin: number;
  adWaitSeconds: number;
  isActive: boolean;
}

export default function OpenPassSettingsForm({
  canWrite,
  durationMin,
  adWaitSeconds,
  isActive,
}: OpenPassSettingsFormProps) {
  const [state, formAction, pending] = useActionState(updateOpenPassSettings, initialState);

  return (
    <form
      action={formAction}
      className="mb-6 grid grid-cols-1 gap-4 rounded-xl border border-slate-800 bg-slate-900 p-4 sm:grid-cols-3"
    >
      <label className="flex flex-col gap-1 text-sm text-slate-300">
        프리패스 이용시간
        <select
          name="durationMin"
          defaultValue={durationMin}
          disabled={!canWrite}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 disabled:opacity-50"
        >
          {DURATION_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-sm text-slate-300">
        광고 확인 대기시간
        <select
          name="adWaitSeconds"
          defaultValue={adWaitSeconds}
          disabled={!canWrite}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 disabled:opacity-50"
        >
          {WAIT_SECONDS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </label>

      <div className="flex flex-col justify-end gap-2">
        <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
          <input
            type="checkbox"
            name="isActive"
            defaultChecked={isActive}
            disabled={!canWrite}
            className="accent-indigo-500"
          />
          프리패스 기능 활성화
        </label>
        {canWrite && (
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "설정 저장"}
          </button>
        )}
      </div>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          설정이 저장되었습니다. 앱/웹에 즉시 반영됩니다.
        </p>
      )}
    </form>
  );
}
