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
  adHelpMessage: string;
  adGuideTitle: string;
  adGuideText: string;
}

export default function OpenPassSettingsForm({
  canWrite,
  durationMin,
  adWaitSeconds,
  isActive,
  adHelpMessage,
  adGuideTitle,
  adGuideText,
}: OpenPassSettingsFormProps) {
  const [state, formAction, pending] = useActionState(updateOpenPassSettings, initialState);

  return (
    <form
      action={formAction}
      className="mb-6 flex flex-col gap-4 rounded-xl border border-slate-200 bg-white p-4"
    >
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <label className="flex flex-col gap-1 text-sm text-slate-600">
          프리패스 이용시간
          <select
            name="durationMin"
            defaultValue={durationMin}
            disabled={!canWrite}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          >
            {DURATION_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-1 text-sm text-slate-600">
          광고 확인 대기시간
          <select
            name="adWaitSeconds"
            defaultValue={adWaitSeconds}
            disabled={!canWrite}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          >
            {WAIT_SECONDS_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>

        <div className="flex flex-col justify-end gap-2">
          <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
            <input
              type="checkbox"
              name="isActive"
              defaultChecked={isActive}
              disabled={!canWrite}
              className="accent-indigo-500"
            />
            프리패스 기능 활성화
          </label>
        </div>
      </div>

      {/* [프리패스 UI 문구 관리자 연동] "?" 도움말 팝업 + 아이콘 바로 아래
          안내 제목/문구 — 앱 바텀시트에 그대로 실시간 반영된다. */}
      <div className="grid grid-cols-1 gap-4 border-t border-slate-200 pt-4 sm:grid-cols-2">
        <label className="flex flex-col gap-1 text-sm text-slate-600">
          안내 제목 (느낌표 아이콘 바로 아래 제목)
          <input
            type="text"
            name="adGuideTitle"
            defaultValue={adGuideTitle}
            disabled={!canWrite}
            placeholder='예: "사주"는 프리패스로 열람할 수 있어요'
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          />
        </label>

        <label className="flex flex-col gap-1 text-sm text-slate-600">
          안내 문구 (제목 바로 아래 설명)
          <input
            type="text"
            name="adGuideText"
            defaultValue={adGuideText}
            disabled={!canWrite}
            placeholder="예: 쿠팡 파트너스 광고를 확인하면 1시간 동안 모든 콘텐츠를 무료로 이용할 수 있어요."
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          />
        </label>

        <label className="col-span-full flex flex-col gap-1 text-sm text-slate-600">
          도움말 팝업 문구 (물음표 아이콘 탭 시 뜨는 안내창 내용)
          <textarea
            name="adHelpMessage"
            defaultValue={adHelpMessage}
            disabled={!canWrite}
            rows={3}
            placeholder="예: 쿠팡 파트너스 활동을 통해 일정 수수료를 지급받는 제휴 광고예요."
            className="resize-none rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          />
        </label>
      </div>

      {canWrite && (
        <div className="flex justify-end">
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "설정 저장"}
          </button>
        </div>
      )}

      {state.error && (
        <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          설정이 저장되었습니다. 앱/웹에 즉시 반영됩니다.
        </p>
      )}
    </form>
  );
}
