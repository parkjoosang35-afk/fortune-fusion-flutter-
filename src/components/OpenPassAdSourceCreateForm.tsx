"use client";

// 열림패스 광고소스 신규 등록 폼. [사용자 요청] §6-3
import { useActionState, useRef } from "react";
import { createOpenPassAdSource, type AdSourceFormState } from "@/app/actions/open-pass-ad-sources";
import { AD_SOURCE_TYPES, AD_SOURCE_TYPE_LABELS } from "@/lib/open-pass-constants";

const initialState: AdSourceFormState = {};

export default function OpenPassAdSourceCreateForm({
  canWrite,
  attachmentOptions,
}: {
  canWrite: boolean;
  attachmentOptions: Array<{ id: number; fileName: string }>;
}) {
  const [state, formAction, pending] = useActionState(createOpenPassAdSource, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 광고소스 등록</h2>

      <input
        type="text"
        name="sourceName"
        placeholder="광고소스명 (예: AdMob 리워드 - 열림패스)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="sourceType"
        defaultValue="admob_rewarded"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      >
        {AD_SOURCE_TYPES.map((t) => (
          <option key={t} value={t}>
            {AD_SOURCE_TYPE_LABELS[t]}
          </option>
        ))}
      </select>
      <input
        type="text"
        name="networkName"
        placeholder="네트워크명 (예: Google AdMob)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />

      <input
        type="text"
        name="adUnitId"
        placeholder="adUnitId"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="placementId"
        placeholder="placementId (선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="rewardType"
        placeholder="rewardType (예: open_pass_minutes)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />

      <input
        type="number"
        name="rewardValue"
        placeholder="보상 값(rewardValue)"
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="cooldownSeconds"
        placeholder="쿨다운(초)"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="dailyLimit"
        placeholder="일일 제한 횟수(선택)"
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="priority"
        placeholder="우선순위(작을수록 우선)"
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />

      <select
        name="fallbackAttachmentId"
        defaultValue=""
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      >
        <option value="">fallback 첨부파일 없음(기본 안내 문구 사용)</option>
        {attachmentOptions.map((a) => (
          <option key={a.id} value={a.id}>
            {a.fileName}
          </option>
        ))}
      </select>
      <input
        type="datetime-local"
        name="startAt"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        title="노출 시작 시각(선택)"
      />
      <input
        type="datetime-local"
        name="endAt"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        title="노출 종료 시각(선택)"
      />
      <input
        type="number"
        name="simulatedDurationSeconds"
        placeholder="[테스트] 가짜 시청시간(초, mock_rewarded_* 전용, 권장 3~5)"
        min={1}
        max={60}
        defaultValue={4}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="failMode"
        placeholder="[테스트] 실패사유(mock_rewarded_fail 전용, 예: network_error)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />

      <div className="flex flex-wrap items-center gap-3 md:col-span-4">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="failoverEnabled" defaultChecked className="accent-indigo-500" /> failover 사용
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="testModeEnabled" className="accent-indigo-500" /> 테스트 모드
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" /> 활성화
        </label>
      </div>

      <p className="col-span-full text-xs text-slate-500">
        타입을 <b className="text-slate-600">[테스트]</b>로 시작하는 항목(mock_rewarded_*)을 선택하면 실제 광고 SDK
        연동 없이 항상 같은 결과(성공/실패/no-fill/중도취소/타임아웃)로 동작하는 테스트 전용 광고소스가 됩니다.
        앞으로 이 5개 타입을 각각 하나씩 등록해 테스트랩에서 사용하세요.
      </p>
      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          광고소스가 등록되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "등록 중..." : "광고소스 등록"}
        </button>
      </div>
    </form>
  );
}
