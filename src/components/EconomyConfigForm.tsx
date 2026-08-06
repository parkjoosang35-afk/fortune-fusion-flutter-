"use client";

// 복(福) 경제 설정 폼 — Phase4(관리자 대시보드, 옵션B).
// economy_config 키(send_refund_rate/daily_send_limit/refund_rate)를 관리자가
// 슬라이더+숫자입력으로 즉시 조정할 수 있게 한다(코드 재배포 없이 경제 튜닝).
import { useActionState } from "react";
import { updateEconomyConfig, type EconomyConfigFormState } from "@/app/actions/economy-config";
import { ECONOMY_CONFIG_KEYS } from "@/lib/economy-config-meta";

const initialState: EconomyConfigFormState = {};

interface ConfigRow {
  key: string;
  value: number;
  updatedAt: string | null;
  updatedBy: string | null;
}

function ConfigSlider({ canWrite, row }: { canWrite: boolean; row: ConfigRow }) {
  const meta = ECONOMY_CONFIG_KEYS.find((k) => k.key === row.key);
  const [state, formAction, pending] = useActionState(updateEconomyConfig, initialState);

  if (!meta) return null;

  const isRate = meta.unit === "rate";
  const isFlag = meta.unit === "flag";

  return (
    <form
      action={formAction}
      className="rounded-xl border border-slate-200 bg-white p-4"
    >
      <input type="hidden" name="key" value={meta.key} />
      <div className="mb-2 flex items-baseline justify-between">
        <p className="text-sm font-semibold text-slate-900">{meta.label}</p>
        <p className="text-xs text-slate-500">key: {meta.key}</p>
      </div>
      <p className="mb-3 text-xs text-slate-500">{meta.description}</p>

      <div className="flex items-center gap-3">
        <input
          type="range"
          name="valueRange"
          min={meta.min}
          max={meta.max}
          step={meta.step}
          defaultValue={row.value}
          disabled={!canWrite}
          onChange={(e) => {
            const numberInput = e.currentTarget.form?.elements.namedItem("value") as HTMLInputElement | null;
            if (numberInput) numberInput.value = e.currentTarget.value;
          }}
          className="h-2 flex-1 cursor-pointer accent-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        />
        <input
          type="number"
          name="value"
          min={meta.min}
          max={meta.max}
          step={meta.step}
          defaultValue={row.value}
          disabled={!canWrite}
          onChange={(e) => {
            const rangeInput = e.currentTarget.form?.elements.namedItem("valueRange") as HTMLInputElement | null;
            if (rangeInput) rangeInput.value = e.currentTarget.value;
          }}
          className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1.5 text-right text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
        />
        <span className="w-10 text-xs text-slate-500">{isRate || isFlag ? "" : "개"}</span>
      </div>

      {isRate && (
        <p className="mt-1 text-xs text-indigo-700">
          현재 값: {(row.value * 100).toFixed(0)}%
        </p>
      )}
      {isFlag && (
        <p className="mt-1 text-xs text-indigo-700">
          현재 상태: {row.value > 0 ? "🟢 이벤트 중(상향 적용)" : "⚪ 평시"}
        </p>
      )}

      <div className="mt-3 flex items-center justify-between">
        <p className="text-xs text-slate-600">
          {row.updatedAt
            ? `마지막 수정: ${new Date(row.updatedAt).toLocaleString("ko-KR")}${row.updatedBy ? ` (${row.updatedBy})` : ""}`
            : "아직 저장된 값이 없어 코드 기본값이 적용 중입니다."}
        </p>
        {canWrite && (
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {pending ? "저장 중..." : "저장"}
          </button>
        )}
      </div>

      {state.error && (
        <p className="mt-2 rounded-lg bg-red-100 px-3 py-2 text-xs text-red-700">{state.error}</p>
      )}
      {state.success && (
        <p className="mt-2 rounded-lg bg-emerald-100 px-3 py-2 text-xs text-emerald-700">
          저장되었습니다. 이후 API 호출부터 즉시 반영됩니다.
        </p>
      )}
    </form>
  );
}

export default function EconomyConfigForm({
  canWrite,
  rows,
}: {
  canWrite: boolean;
  rows: ConfigRow[];
}) {
  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
      {ECONOMY_CONFIG_KEYS.map((meta) => {
        const row =
          rows.find((r) => r.key === meta.key) ?? {
            key: meta.key,
            value: meta.defaultValue,
            updatedAt: null,
            updatedBy: null,
          };
        return <ConfigSlider key={meta.key} canWrite={canWrite} row={row} />;
      })}
    </div>
  );
}
