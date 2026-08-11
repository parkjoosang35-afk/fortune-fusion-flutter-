"use client";

// [신통방통 복주머니 광고 적립 시스템] 광고 신규 등록 폼.
// OpenPassAdSourceCreateForm.tsx 패턴을 그대로 재사용.
import { useActionState, useRef, useState } from "react";
import { createFortuneAd, type FortuneAdFormState } from "@/app/actions/fortune-ads";

const initialState: FortuneAdFormState = {};

const AD_TYPE_LABELS: Record<string, string> = {
  image: "이미지",
  video: "동영상",
  external: "외부 광고(URL)",
  network: "광고플랫폼 연동(스크립트/HTML)",
};

export default function FortuneAdCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createFortuneAd, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [adType, setAdType] = useState("image");

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setAdType("image");
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 광고 등록</h2>

      <input
        type="text"
        name="title"
        placeholder="광고명"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="adType"
        value={adType}
        onChange={(e) => setAdType(e.target.value)}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      >
        {Object.entries(AD_TYPE_LABELS).map(([value, label]) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
      <input
        type="text"
        name="description"
        placeholder="설명(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />

      {adType === "image" && (
        <input
          type="text"
          name="imageUrl"
          placeholder="이미지 URL"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4"
        />
      )}
      {adType === "video" && (
        <input
          type="text"
          name="videoUrl"
          placeholder="동영상 URL"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4"
        />
      )}
      {adType === "external" && (
        <input
          type="text"
          name="externalUrl"
          placeholder="외부 광고 URL"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4"
        />
      )}
      {adType === "network" && (
        <textarea
          name="adSourceHtml"
          placeholder="광고플랫폼 연동 스크립트/HTML"
          rows={3}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4"
        />
      )}

      <input
        type="number"
        name="rewardAmount"
        placeholder="1회 시청 보상(복주머니 개수)"
        min={1}
        defaultValue={10}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="watchSeconds"
        placeholder="최소 시청 시간(초)"
        min={1}
        defaultValue={15}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="perUserDailyLimit"
        placeholder="회원당 하루 최대 시청 횟수"
        min={1}
        defaultValue={3}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="dailyLimitReward"
        placeholder="하루 최대 지급 총량(선택, 전체 유저 합산)"
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

      <div className="flex flex-wrap items-center gap-3 md:col-span-4">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" /> 활성화(즉시 노출)
        </label>
      </div>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          광고가 등록되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "등록 중..." : "광고 등록"}
        </button>
      </div>
    </form>
  );
}
