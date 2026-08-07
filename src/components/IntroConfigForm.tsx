"use client";

// [인트로 전면 개편] 앱 첫 진입(스플래시/카드1 프리패스/카드2 복주머니/시작화면) 설정 폼.
// "자유 배치/좌표/애니메이션 수치"는 주지 않고, 운영에 필요한 최소 항목만 노출한다.
import { useActionState } from "react";
import { updateIntroConfig, type IntroConfigFormState } from "@/app/actions/intro-config";

const initialState: IntroConfigFormState = {};

export interface IntroConfigRow {
  isEnabled: boolean;
  showOnlyFirstLaunch: boolean;
  showSkipButton: boolean;
  showGuestHint: boolean;
  splashTitle: string;
  splashSubtitle: string | null;
  card1Title: string;
  card1Description: string;
  card1ImageUrl: string | null;
  card2Title: string;
  card2Description: string;
  card2ImageUrl: string | null;
  ctaTitle: string;
  ctaSubtitle: string;
  signupRewardText: string;
  signupRewardAmount: number;
}

function Toggle({ name, label, defaultChecked, disabled }: { name: string; label: string; defaultChecked: boolean; disabled: boolean }) {
  return (
    <label className="flex items-center gap-2 text-sm text-slate-700">
      <input type="checkbox" name={name} defaultChecked={defaultChecked} disabled={disabled} className="h-4 w-4 rounded accent-indigo-600 disabled:opacity-50" />
      {label}
    </label>
  );
}

function TextField({
  name,
  label,
  defaultValue,
  disabled,
  maxLength,
  multiline,
}: {
  name: string;
  label: string;
  defaultValue: string;
  disabled: boolean;
  maxLength?: number;
  multiline?: boolean;
}) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-slate-600">{label}</label>
      {multiline ? (
        <textarea
          name={name}
          defaultValue={defaultValue}
          disabled={disabled}
          maxLength={maxLength}
          rows={2}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
        />
      ) : (
        <input
          type="text"
          name={name}
          defaultValue={defaultValue}
          disabled={disabled}
          maxLength={maxLength}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
        />
      )}
    </div>
  );
}

export default function IntroConfigForm({ canWrite, row }: { canWrite: boolean; row: IntroConfigRow }) {
  const [state, formAction, pending] = useActionState(updateIntroConfig, initialState);

  return (
    <form action={formAction} className="space-y-6">
      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-base font-semibold text-slate-900">노출 정책</h2>
        <div className="flex flex-wrap gap-4">
          <Toggle name="isEnabled" label="인트로 on/off" defaultChecked={row.isEnabled} disabled={!canWrite} />
          <Toggle name="showOnlyFirstLaunch" label="첫 실행 시만 노출" defaultChecked={row.showOnlyFirstLaunch} disabled={!canWrite} />
          <Toggle name="showSkipButton" label="스킵 버튼 노출" defaultChecked={row.showSkipButton} disabled={!canWrite} />
          <Toggle name="showGuestHint" label="'로그인 없이 둘러보기' 문구 노출" defaultChecked={row.showGuestHint} disabled={!canWrite} />
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-base font-semibold text-slate-900">1단계 · 브랜드 스플래시</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <TextField name="splashTitle" label="앱명(타이틀)" defaultValue={row.splashTitle} disabled={!canWrite} maxLength={30} />
          <TextField name="splashSubtitle" label="짧은 카피(선택, 비우면 무카피)" defaultValue={row.splashSubtitle ?? ""} disabled={!canWrite} maxLength={60} />
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-base font-semibold text-slate-900">2단계 · 카드1(프리패스)</h2>
        <div className="grid grid-cols-1 gap-3">
          <TextField name="card1Title" label="제목" defaultValue={row.card1Title} disabled={!canWrite} maxLength={60} />
          <TextField name="card1Description" label="설명" defaultValue={row.card1Description} disabled={!canWrite} maxLength={200} multiline />
          <TextField name="card1ImageUrl" label="대표 이미지 URL(선택)" defaultValue={row.card1ImageUrl ?? ""} disabled={!canWrite} maxLength={500} />
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-base font-semibold text-slate-900">3단계 · 카드2(복주머니)</h2>
        <div className="grid grid-cols-1 gap-3">
          <TextField name="card2Title" label="제목" defaultValue={row.card2Title} disabled={!canWrite} maxLength={60} />
          <TextField name="card2Description" label="설명" defaultValue={row.card2Description} disabled={!canWrite} maxLength={200} multiline />
          <TextField name="card2ImageUrl" label="대표 이미지 URL(선택)" defaultValue={row.card2ImageUrl ?? ""} disabled={!canWrite} maxLength={500} />
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-5">
        <h2 className="mb-3 text-base font-semibold text-slate-900">4단계 · 시작 화면(CTA)</h2>
        <div className="grid grid-cols-1 gap-3">
          <TextField name="ctaTitle" label="제목" defaultValue={row.ctaTitle} disabled={!canWrite} maxLength={60} />
          <TextField name="ctaSubtitle" label="서브 문구" defaultValue={row.ctaSubtitle} disabled={!canWrite} maxLength={120} />
          <TextField name="signupRewardText" label="가입 보상 노출 문구" defaultValue={row.signupRewardText} disabled={!canWrite} maxLength={80} />
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">
              회원가입 보상 수량(복주머니 개수) — 저장 시 실제 지급 정책(point_policies.signup_reward)도 함께 갱신됩니다
            </label>
            <input
              type="number"
              name="signupRewardAmount"
              min={0}
              max={100000}
              defaultValue={row.signupRewardAmount}
              disabled={!canWrite}
              className="w-40 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
            />
          </div>
        </div>
      </div>

      {state.error && <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>}
      {state.success && (
        <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          저장되었습니다. Flutter 앱은 다음 인트로 설정 조회 시점부터 즉시 반영됩니다.
        </p>
      )}

      {canWrite && (
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "저장 중..." : "저장"}
        </button>
      )}
    </form>
  );
}
