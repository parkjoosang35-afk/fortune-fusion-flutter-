"use client";

// [관리자 간소화·실운영 업데이트, 2026-10] §2/§3 쿠팡 프리패스는 "횟수제"로
// 운영되므로(claim-ad.ts → claimCoupangDailyPass()), 실제 지급량/일일한도/
// 유효기간을 좌우하는 grantCount/dailyClaimLimit/validityDays를 관리자가
// 직접 조정할 수 있도록 노출한다. 과거 폼이 노출하던 durationMin(이용시간)/
// categoryMaxUsage(카테고리별 최대 이용횟수)는 이 정책(grantCount != null)에서는
// claimCoupangDailyPass()가 전혀 읽지 않는 레거시 시간제 전용 필드임을
// schema.prisma 주석(§9.2)으로 확인했다 — 값을 바꿔도 쿠팡 프리패스 동작에
// 아무 영향이 없어 "설정은 있지만 실제로는 반영 안 되는" 혼란을 유발했으므로,
// 이 화면에서는 입력 폼을 제거하고 레거시 값 자체는 DB에 보존만 한다(삭제 금지,
// 과거 발급된 UserPass의 expiresAt 계산 등에는 여전히 쓰일 수 있음).
import { useActionState } from "react";
import { updateOpenPassSettings, type OpenPassSettingsFormState } from "@/app/actions/pass-policies";

const initialState: OpenPassSettingsFormState = {};

const WAIT_SECONDS_OPTIONS = [
  { value: 4, label: "4초" },
  { value: 5, label: "5초" },
  { value: 10, label: "10초" },
];

// [§2/§3 쿠팡 프리패스 횟수제 실제 파라미터]
const GRANT_COUNT_OPTIONS = [
  { value: 1, label: "1회" },
  { value: 2, label: "2회" },
  { value: 3, label: "3회" },
  { value: 5, label: "5회" },
];

const DAILY_CLAIM_LIMIT_OPTIONS = [
  { value: 1, label: "하루 1회" },
  { value: 2, label: "하루 2회" },
  { value: 3, label: "하루 3회" },
];

// "" 값은 무제한(null, 만료 없음)을 의미한다.
const VALIDITY_DAYS_OPTIONS = [
  { value: "1", label: "1일" },
  { value: "3", label: "3일" },
  { value: "7", label: "7일" },
  { value: "30", label: "30일" },
  { value: "", label: "무제한(만료 없음)" },
];

interface OpenPassSettingsFormProps {
  canWrite: boolean;
  durationMin: number;
  adWaitSeconds: number;
  isActive: boolean;
  adHelpMessage: string;
  adGuideTitle: string;
  adGuideText: string;
  categoryMaxUsage: number | null;
  grantCount: number | null;
  dailyClaimLimit: number | null;
  validityDays: number | null;
}

export default function OpenPassSettingsForm({
  canWrite,
  durationMin,
  adWaitSeconds,
  isActive,
  adHelpMessage,
  adGuideTitle,
  adGuideText,
  categoryMaxUsage,
  grantCount,
  dailyClaimLimit,
  validityDays,
}: OpenPassSettingsFormProps) {
  const [state, formAction, pending] = useActionState(updateOpenPassSettings, initialState);

  return (
    <form
      action={formAction}
      className="mb-6 flex flex-col gap-4 rounded-xl border border-slate-200 bg-white p-4"
    >
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <label className="flex flex-col gap-1 text-sm text-slate-600">
          쿠팡 프리패스 지급 횟수
          <select
            name="grantCount"
            defaultValue={grantCount ?? 2}
            disabled={!canWrite}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          >
            {GRANT_COUNT_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          <span className="text-xs text-slate-400">
            쿠팡 광고를 확인하고 받을 때마다 지급되는 결과보기 이용 횟수입니다.
          </span>
        </label>

        <label className="flex flex-col gap-1 text-sm text-slate-600">
          일일 획득 제한
          <select
            name="dailyClaimLimit"
            defaultValue={dailyClaimLimit ?? 1}
            disabled={!canWrite}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          >
            {DAILY_CLAIM_LIMIT_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          <span className="text-xs text-slate-400">
            회원 1명이 하루에 쿠팡 프리패스를 최대 몇 번 획득할 수 있는지입니다.
          </span>
        </label>

        <label className="flex flex-col gap-1 text-sm text-slate-600">
          지급 횟수 유효기간
          <select
            name="validityDays"
            defaultValue={validityDays != null ? String(validityDays) : ""}
            disabled={!canWrite}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          >
            {VALIDITY_DAYS_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          <span className="text-xs text-slate-400">
            지급된 결과보기 횟수가 얼마 동안 유효한지입니다(무제한 선택 시 소멸되지 않음).
          </span>
        </label>
      </div>

      <div className="grid grid-cols-1 gap-4 border-t border-slate-200 pt-4 sm:grid-cols-3">
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

      {/* [관리자 간소화·실운영 업데이트, 2026-10] §3 프리패스는 횟수제로 운영되므로
          시간 기반 설정(이용시간/카테고리별 최대 이용횟수)은 이 정책(쿠팡, grantCount!=null)
          판정에서 더 이상 읽히지 않는다. 데이터는 삭제하지 않고(§9.2) 참고용 읽기전용으로만
          표시해 "설정은 바뀌는데 실제로는 반영 안 되는" 혼란을 없앤다. */}
      <details className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-xs text-slate-500">
        <summary className="cursor-pointer select-none font-medium text-slate-500">
          레거시 시간제 설정값 (현재 미사용 · 참고용)
        </summary>
        <div className="mt-2 flex flex-wrap gap-4">
          <span>이용시간: {durationMin}분 (쿠팡 프리패스는 횟수제라 이 값을 사용하지 않습니다)</span>
          <span>카테고리별 최대 이용횟수: {categoryMaxUsage != null ? `${categoryMaxUsage}회` : "무제한"}</span>
        </div>
      </details>

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
