"use client";

// 소원방(Wish Room) 관리자 설정 폼 — WishConfigForm.tsx(소원성)와 동일한
// useActionState + 개별 폼 카드 패턴. valueType(number/boolean)에 따라
// 입력 컨트롤을 분기한다(과설계 방지: 신규 UI 컴포넌트 라이브러리 없이 순수 HTML).
import { useActionState } from "react";
import { updateWishRoomConfig, type WishRoomConfigFormState } from "@/app/actions/wish-room-config";
import { WISH_ROOM_CONFIG_KEYS } from "@/lib/wish-room-config-meta";

const initialState: WishRoomConfigFormState = {};

interface ConfigRow {
  key: string;
  value: string;
  updatedAt: string | null;
  updatedBy: string | null;
}

function ConfigCard({ canWrite, row }: { canWrite: boolean; row: ConfigRow }) {
  const meta = WISH_ROOM_CONFIG_KEYS.find((k) => k.key === row.key);
  const [state, formAction, pending] = useActionState(updateWishRoomConfig, initialState);

  if (!meta) return null;

  const isOrphan = meta.key === "wish_room_representative_change_cooldown_hours";

  return (
    <form
      action={formAction}
      className={`rounded-xl border p-4 ${
        isOrphan ? "border-amber-300 bg-amber-50" : "border-slate-200 bg-white"
      }`}
    >
      <input type="hidden" name="key" value={meta.key} />
      <div className="mb-2 flex items-baseline justify-between">
        <p className="text-sm font-semibold text-slate-900">{meta.label}</p>
        <p className="text-xs text-slate-500">key: {meta.key}</p>
      </div>
      <p className="mb-3 whitespace-pre-line text-xs text-slate-500">{meta.description}</p>

      {meta.valueType === "number" && (
        <div className="flex items-center gap-3">
          <input
            type="number"
            name="value"
            min={meta.min}
            max={meta.max}
            step={meta.step}
            defaultValue={row.value}
            disabled={!canWrite}
            className="w-32 rounded-lg border border-slate-300 bg-white px-2 py-1.5 text-right text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
          />
          <span className="text-xs text-slate-500">{meta.unit}</span>
        </div>
      )}

      {meta.valueType === "boolean" && (
        <select
          name="value"
          defaultValue={row.value}
          disabled={!canWrite}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 disabled:opacity-50"
        >
          <option value="true">ON (활성화)</option>
          <option value="false">OFF (비활성화)</option>
        </select>
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

export default function WishRoomConfigForm({
  canWrite,
  rows,
}: {
  canWrite: boolean;
  rows: ConfigRow[];
}) {
  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      {WISH_ROOM_CONFIG_KEYS.map((meta) => {
        const row =
          rows.find((r) => r.key === meta.key) ?? {
            key: meta.key,
            value: meta.defaultValue,
            updatedAt: null,
            updatedBy: null,
          };
        return <ConfigCard key={meta.key} canWrite={canWrite} row={row} />;
      })}
    </div>
  );
}
