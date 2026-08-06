"use client";

import { useActionState, useRef } from "react";
import { createPassPolicy, type PassPolicyFormState } from "@/app/actions/pass-policies";
import { SCOPE_PRESETS, SCOPE_PRESET_LABELS } from "@/lib/open-pass-constants";

const initialState: PassPolicyFormState = {};

const PASS_TYPE_OPTIONS = [
  { value: "ad", label: "광고 시청 (ad)" },
  { value: "partner", label: "파트너 제휴 (partner)" },
  { value: "subscription", label: "구독 (subscription)" },
  { value: "event", label: "이벤트 (event)" },
];

const SCOPE_OPTIONS = Object.keys(SCOPE_PRESETS) as (keyof typeof SCOPE_PRESETS)[];

export default function PassPolicyCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createPassPolicy, initialState);
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
      <h2 className="col-span-full text-sm font-semibold text-slate-900">새 프리패스 상품 추가</h2>
      <input
        type="text"
        name="name"
        placeholder="정책명 (예: 광고 시청 3시간 패스)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="passType"
        defaultValue="ad"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      >
        {PASS_TYPE_OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <input
        type="number"
        name="durationMin"
        placeholder="지속시간(분) 예: 60/180/1440"
        required
        min={1}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="dailyLimit"
        placeholder="1일 최대 발급 횟수(선택, 무제한=공란)"
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="bonusPoint"
        placeholder="함께 지급할 포인트(선택)"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="text"
        name="linkUrl"
        placeholder="광고/파트너 랜딩 URL(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="ctaText"
        placeholder="홈 화면 CTA 버튼 문구(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="bannerImageUrl"
        placeholder="배너 이미지 URL(선택)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />

      <hr className="col-span-full border-slate-200" />
      <p className="col-span-full text-xs font-medium text-slate-500">§3 프리패스 운영 확장 필드</p>

      <input
        type="text"
        name="description"
        placeholder="설명 문구(선택, 상품 상세 안내용)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <select
        name="scopePreset"
        defaultValue="all_fortune"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      >
        {SCOPE_OPTIONS.map((key) => (
          <option key={key} value={key}>
            적용 범위: {SCOPE_PRESET_LABELS[key]}
          </option>
        ))}
      </select>
      <input
        type="number"
        name="happyMoneyPrice"
        placeholder="복주머니 구매 가격(선택, 공란=구매 불가)"
        min={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <input
        type="number"
        name="displayPriority"
        placeholder="노출 우선순위(숫자 클수록 우선)"
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
      />
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        시작일(선택, 공란=상시)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        종료일(선택, 공란=상시)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
      </label>
      <input
        type="text"
        name="lockCopy"
        placeholder="잠금 안내 문구(예: 프리패스로 전체 운세 열기)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="acquireCopy"
        placeholder="획득 안내 문구(예: 프리패스가 발급되었습니다!)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <input
        type="text"
        name="expireCopy"
        placeholder="만료 안내 문구(예: 프리패스가 만료되었어요)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
      />
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="adRewardEnabled" defaultChecked className="accent-indigo-500" />
        광고로 획득 가능
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isFeatured" className="accent-indigo-500" />
        대표 노출
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="testModeAllowed" defaultChecked className="accent-indigo-500" />
        테스트모드 허용(테스트랩 대상)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          정책이 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <p className="mb-2 text-xs text-slate-500">
          Flutter 앱 홈 화면의 &quot;프리패스 받기&quot; 섹션은 passType이 ad/partner인 활성
          정책만 CTA 카드로 노출합니다(claim-ad/claim-partner API 대응).
        </p>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "정책 추가"}
        </button>
      </div>
    </form>
  );
}
