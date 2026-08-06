"use client";

import { useActionState, useState } from "react";
import {
  updateFactorWeight,
  toggleFactorWeightActive,
  type CompatibilityWeightFormState,
} from "@/app/actions/compatibility-weights";

export interface CompatibilityWeightRowProps {
  item: {
    id: number;
    factorType: string;
    weight: number;
    isActive: boolean;
    updatedAt: Date;
  };
  canWrite: boolean;
}

const initialState: CompatibilityWeightFormState = {};

const FACTOR_LABEL: Record<string, string> = {
  saju: "사주",
  mbti: "MBTI",
  interest: "취미/관심사",
  value: "가치관",
  activity_pattern: "활동패턴",
};

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

// [useEffect 미사용 이유] React 컴파일러 규칙(set-state-in-effect)에 따라
//   effect 내부에서 setState를 직접 호출하지 않는다(원칙⑤ 소단위 개발 —
//   기존 프로젝트 전체가 useEffect 없이 useActionState만으로 폼 상태를
//   관리하는 컨벤션을 따름, BannerRow/CommentRow 등 전례 재확인). 대신
//   부모(CompatibilityWeightTable)가 item.updatedAt을 포함한 key를 부여하여,
//   저장 성공 후 서버 재조회 데이터가 반영되면 컴포넌트가 자동으로
//   리마운트되어 editing 상태가 초기값(false)으로 리셋된다. 경고 메시지는
//   각 액션의 반환값(updateState.warning/toggleState.warning)을 이 행
//   자체에서 직접 렌더링한다(별도 상태 전파 불필요).
export default function CompatibilityWeightRow({ item, canWrite }: CompatibilityWeightRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateFactorWeight, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleFactorWeightActive,
    initialState
  );

  const warning = updateState.warning ?? toggleState.warning;

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td className="px-4 py-3 text-slate-700">{FACTOR_LABEL[item.factorType] ?? item.factorType}</td>
        <td colSpan={canWrite ? 4 : 3} className="px-4 py-3">
          <form action={updateAction} className="flex items-center gap-2">
            <input type="hidden" name="id" value={item.id} />
            <input
              type="number"
              name="weight"
              step="0.01"
              min={0}
              max={1}
              defaultValue={item.weight}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <button
              type="submit"
              disabled={updatePending}
              className="rounded-lg bg-indigo-600 px-3 py-1 text-xs font-semibold text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              저장
            </button>
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100"
            >
              취소
            </button>
            {updateState.error && <span className="text-xs text-rose-700">{updateState.error}</span>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <>
      <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
        <td className="px-4 py-3 font-medium text-slate-700">{FACTOR_LABEL[item.factorType] ?? item.factorType}</td>
        <td className="px-4 py-3 text-slate-700">{item.weight.toFixed(2)}</td>
        <td className="px-4 py-3">
          {item.isActive ? (
            <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
          ) : (
            <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
          )}
        </td>
        <td className="px-4 py-3 text-slate-500">{fmtDate(item.updatedAt)}</td>
        {canWrite && (
          <td className="px-4 py-3">
            <div className="flex gap-2">
              <button
                onClick={() => setEditing(true)}
                className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-100"
              >
                가중치 수정
              </button>
              <form action={toggleAction}>
                <input type="hidden" name="id" value={item.id} />
                <input type="hidden" name="isActive" value={(!item.isActive).toString()} />
                <button
                  type="submit"
                  disabled={togglePending}
                  className="rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
                >
                  {item.isActive ? "비활성화" : "활성화"}
                </button>
              </form>
            </div>
          </td>
        )}
      </tr>
      {warning && (
        <tr className="border-b border-slate-200/60 bg-amber-100">
          <td colSpan={canWrite ? 5 : 4} className="px-4 py-2 text-xs text-amber-700">
            ⚠️ {warning}
          </td>
        </tr>
      )}
    </>
  );
}
