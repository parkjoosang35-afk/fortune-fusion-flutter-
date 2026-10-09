"use client";

// [신통방통 관리자 통합 간소화 실행 지시서 - task 4 "광고관리 통합메뉴"]
// AdMob/AdSense 설정 패널. SystemSettingCreateForm.tsx 패턴(useActionState)을 재사용.
import { useActionState } from "react";
import {
  updateAdmobConfig,
  updateAdsenseConfig,
  type AdPlatformConfigFormState,
} from "@/app/actions/ad-platform-config";

const initialState: AdPlatformConfigFormState = {};

interface AdPlatformConfigRow {
  id: number;
  platform: string;
  isEnabled: boolean;
  publisherId: string | null;
  showPlaceholderWhenDisabled: boolean;
  surfaceConfigJson: string | null;
  formatConfigJson: string | null;
  note: string | null;
  updatedAt: Date;
  updatedBy: string | null;
}

const SURFACE_LABELS: Record<string, string> = {
  home: "홈",
  sajuRenewal: "정통사주",
  tarot: "타로",
  wishRoom: "소원방",
  guinji: "귀인지도",
  face: "관상",
  palm: "손금",
};

const FORMAT_LABELS: Record<string, string> = {
  banner: "배너",
  inPage: "인페이지",
  anchor: "앵커(하단고정)",
  vignette: "전면(비네트)",
};

function safeParseJson(json: string | null): Record<string, boolean> {
  if (!json) return {};
  try {
    return JSON.parse(json);
  } catch {
    return {};
  }
}

export function AdmobConfigCard({ config, canWrite }: { config: AdPlatformConfigRow; canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(updateAdmobConfig, initialState);

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-base font-semibold text-slate-900">AdMob (앱 광고)</h3>
        <span
          className={`rounded-full px-2 py-0.5 text-xs font-medium ${
            config.isEnabled ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-500"
          }`}
        >
          {config.isEnabled ? "노출 중" : "노출 중지"}
        </span>
      </div>

      <p className="mb-4 whitespace-pre-line text-xs text-slate-500">{config.note}</p>

      <form action={formAction} className="space-y-3">
        <label className="flex items-center gap-2 text-sm text-slate-900">
          <input
            type="checkbox"
            name="isEnabled"
            defaultChecked={config.isEnabled}
            disabled={!canWrite}
            className="h-4 w-4 rounded border-slate-300"
          />
          광고 노출 활성화 (킬스위치 — 재배포 없이 즉시 반영)
        </label>

        <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
          ⚠️ 실제 Ad Unit ID(배너/전면/보상형) 전환은 이 화면에서 할 수 없습니다. 앱 빌드 시{" "}
          <code className="rounded bg-amber-100 px-1">--dart-define=ADMOB_USE_REAL_IDS=true</code> 플래그로만
          전환되며, 이는 무효 트래픽으로 인한 AdMob 계정정지 위험을 방지하기 위한 의도적 안전장치입니다.
        </p>

        {canWrite && (
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "저장"}
          </button>
        )}

        {state.error && (
          <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
        )}
        {state.success && (
          <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">저장되었습니다.</p>
        )}
      </form>

      <p className="mt-3 text-xs text-slate-400">
        최근 수정: {config.updatedBy ?? "-"} · {new Date(config.updatedAt).toLocaleString("ko-KR")}
      </p>
    </div>
  );
}

export function AdsenseConfigCard({ config, canWrite }: { config: AdPlatformConfigRow; canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(updateAdsenseConfig, initialState);
  const surfaceConfig = safeParseJson(config.surfaceConfigJson);
  const formatConfig = safeParseJson(config.formatConfigJson);

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-base font-semibold text-slate-900">AdSense (웹 광고)</h3>
        <span
          className={`rounded-full px-2 py-0.5 text-xs font-medium ${
            config.isEnabled ? "bg-emerald-100 text-emerald-700" : "bg-slate-100 text-slate-500"
          }`}
        >
          {config.isEnabled ? "노출 중" : "노출 중지"}
        </span>
      </div>

      <p className="mb-4 whitespace-pre-line text-xs text-slate-500">{config.note}</p>

      <form action={formAction} className="space-y-4">
        <label className="flex items-center gap-2 text-sm text-slate-900">
          <input
            type="checkbox"
            name="isEnabled"
            defaultChecked={config.isEnabled}
            disabled={!canWrite}
            className="h-4 w-4 rounded border-slate-300"
          />
          광고 전체 활성화 (재배포 없이 즉시 반영)
        </label>

        <div>
          <label className="mb-1 block text-xs font-medium text-slate-500">
            퍼블리셔 ID (ca-pub-XXXXXXXXXXXXXXXX)
          </label>
          <input
            type="text"
            name="publisherId"
            defaultValue={config.publisherId ?? ""}
            disabled={!canWrite}
            placeholder="ca-pub-1234567890123456"
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:bg-slate-50"
          />
        </div>

        <label className="flex items-center gap-2 text-sm text-slate-900">
          <input
            type="checkbox"
            name="showPlaceholderWhenDisabled"
            defaultChecked={config.showPlaceholderWhenDisabled}
            disabled={!canWrite}
            className="h-4 w-4 rounded border-slate-300"
          />
          비활성 시 플레이스홀더 표시
        </label>

        <div>
          <p className="mb-2 text-xs font-medium text-slate-500">서비스별 노출</p>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {Object.entries(SURFACE_LABELS).map(([key, label]) => (
              <label key={key} className="flex items-center gap-1.5 text-sm text-slate-900">
                <input
                  type="checkbox"
                  name={`surface_${key}`}
                  defaultChecked={!!surfaceConfig[key]}
                  disabled={!canWrite}
                  className="h-4 w-4 rounded border-slate-300"
                />
                {label}
              </label>
            ))}
          </div>
        </div>

        <div>
          <p className="mb-2 text-xs font-medium text-slate-500">포맷별 노출</p>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {Object.entries(FORMAT_LABELS).map(([key, label]) => (
              <label key={key} className="flex items-center gap-1.5 text-sm text-slate-900">
                <input
                  type="checkbox"
                  name={`format_${key}`}
                  defaultChecked={!!formatConfig[key]}
                  disabled={!canWrite}
                  className="h-4 w-4 rounded border-slate-300"
                />
                {label}
              </label>
            ))}
          </div>
        </div>

        {canWrite && (
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "저장"}
          </button>
        )}

        {state.error && (
          <p className="rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">{state.error}</p>
        )}
        {state.success && (
          <p className="rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">저장되었습니다.</p>
        )}
      </form>

      <p className="mt-3 text-xs text-slate-400">
        최근 수정: {config.updatedBy ?? "-"} · {new Date(config.updatedAt).toLocaleString("ko-KR")}
      </p>
    </div>
  );
}
