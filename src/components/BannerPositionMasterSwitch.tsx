"use client";

import { useActionState } from "react";
import {
  bulkToggleBannersByPosition,
  type BannerFormState,
} from "@/app/actions/banners";

// [운세 앱 개발 프롬프트-Task3] CMS 배너 관리 화면 상단에 위치별 마스터
// ON/OFF 스위치를 노출한다. "이 위치의 배너를 전부 켤지/끌지"를 한 번에
// 제어해, 앱 홈 화면의 해당 슬롯을 즉시 노출/숨김할 수 있게 한다.

const POSITION_META: Record<string, { label: string; hint: string }> = {
  home_top: { label: "홈 상단", hint: "인사문구 바로 아래" },
  home_middle: { label: "홈 중단", hint: "AI 추천 카드 위" },
  home_bottom: { label: "홈 하단", hint: "소원방 배너 아래(스크롤 최하단)" },
};

const initialState: BannerFormState = {};

interface PositionSummary {
  positionCode: string;
  total: number;
  active: number;
}

function PositionSwitchCard({
  summary,
  canWrite,
}: {
  summary: PositionSummary;
  canWrite: boolean;
}) {
  const [state, formAction, pending] = useActionState(
    bulkToggleBannersByPosition,
    initialState
  );
  const meta = POSITION_META[summary.positionCode];
  const allActive = summary.total > 0 && summary.active === summary.total;
  const noneActive = summary.active === 0;
  const nextIsActive = !allActive; // 하나라도 꺼져있으면 "전체 켜기"를, 전부 켜져있으면 "전체 끄기"를 제시

  return (
    <div className="flex flex-col justify-between rounded-xl border border-slate-200 bg-white p-4">
      <div>
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold text-slate-900">
            {meta?.label ?? summary.positionCode}
          </p>
          <span
            className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
              allActive
                ? "bg-emerald-100 text-emerald-700"
                : noneActive
                  ? "bg-white text-slate-500"
                  : "bg-amber-100 text-amber-700"
            }`}
          >
            {summary.total === 0
              ? "배너 없음"
              : allActive
                ? "전체 노출중"
                : noneActive
                  ? "전체 비노출"
                  : "일부만 노출"}
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-500">{meta?.hint}</p>
        <p className="mt-2 text-xs text-slate-500">
          활성 {summary.active} / 전체 {summary.total}건
        </p>
      </div>

      <form action={formAction} className="mt-3">
        <input type="hidden" name="positionCode" value={summary.positionCode} />
        <input type="hidden" name="isActive" value={nextIsActive.toString()} />
        <button
          type="submit"
          disabled={!canWrite || pending || summary.total === 0}
          className={`w-full rounded-lg px-3 py-2 text-xs font-medium transition disabled:cursor-not-allowed disabled:opacity-40 ${
            nextIsActive
              ? "bg-indigo-600 text-white hover:bg-indigo-500"
              : "border border-slate-300 text-slate-600 hover:bg-slate-100"
          }`}
        >
          {pending
            ? "처리 중..."
            : nextIsActive
              ? "이 위치 전체 켜기"
              : "이 위치 전체 끄기"}
        </button>
        {state.error && (
          <p className="mt-1 text-[11px] text-red-700">{state.error}</p>
        )}
      </form>
    </div>
  );
}

export default function BannerPositionMasterSwitch({
  summaries,
  canWrite,
}: {
  summaries: PositionSummary[];
  canWrite: boolean;
}) {
  return (
    <div className="mb-6">
      <h3 className="mb-3 text-sm font-semibold text-slate-900">
        📍 위치별 마스터 스위치
      </h3>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {summaries.map((s) => (
          <PositionSwitchCard key={s.positionCode} summary={s} canWrite={canWrite} />
        ))}
      </div>
    </div>
  );
}
