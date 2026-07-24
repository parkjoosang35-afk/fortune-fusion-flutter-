"use client";

// 05§4.4 워크플로우: 확률테이블 수정도 신규 추가와 동일하게 2단계 확인 모달을 거친다
// (수정 근거는 LuckybagRewardPoolCreateForm.tsx 상단 주석 참조). 삭제(deleteLuckybagRewardPool)는
// 05 스펙상 §4.4 대상이 아니므로(확률 값 변경이 아님) 이번 수정 범위에서 제외한다.
import { useActionState, useState } from "react";
import {
  updateLuckybagRewardPool,
  deleteLuckybagRewardPool,
  type LuckybagFormState,
} from "@/app/actions/luckybag";
import ConfirmDangerDialog from "./ConfirmDangerDialog";

interface LuckybagRewardPoolRowProps {
  pool: {
    id: number;
    luckybagProductId: number;
    gradeId: number;
    rewardType: string;
    rewardAmount: number | null;
    probability: number;
  };
  products: { id: number; name: string }[];
  grades: { id: number; name: string; code: string }[];
  canWrite: boolean;
  canDelete: boolean;
}

const REWARD_TYPE_LABEL: Record<string, string> = {
  none: "꽝",
  point: "포인트",
  amulet: "부적",
  giftcard_fragment: "상품권 조각",
};

const initialState: LuckybagFormState = {};

export default function LuckybagRewardPoolRow({
  pool,
  products,
  grades,
  canWrite,
  canDelete,
}: LuckybagRewardPoolRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(
    updateLuckybagRewardPool,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteLuckybagRewardPool,
    initialState
  );

  const productName = products.find((p) => p.id === pool.luckybagProductId)?.name ?? "-";
  const gradeName = grades.find((g) => g.id === pool.gradeId)?.name ?? "-";
  const [confirming, setConfirming] = useState(false);

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={6} className="px-4 py-3">
          <form
            onSubmit={(e) => {
              // 05§4.4: 1단계 제출 시점에는 서버 전송을 막고 2단계 확인만 노출한다.
              if (!confirming) {
                e.preventDefault();
                setConfirming(true);
              }
            }}
            action={updateAction}
            className="flex flex-wrap items-center gap-2"
          >
            <input type="hidden" name="id" value={pool.id} />
            <select
              name="luckybagProductId"
              defaultValue={pool.luckybagProductId}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              {products.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
            <select
              name="gradeId"
              defaultValue={pool.gradeId}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              {grades.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name}
                </option>
              ))}
            </select>
            <select
              name="rewardType"
              defaultValue={pool.rewardType}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              {Object.entries(REWARD_TYPE_LABEL).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
            <input
              type="number"
              name="rewardAmount"
              defaultValue={pool.rewardAmount ?? ""}
              min={0}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="number"
              name="probability"
              defaultValue={pool.probability}
              min={0.0001}
              max={100}
              step={0.0001}
              className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <ConfirmDangerDialog
              confirming={confirming}
              pending={updatePending}
              warningText="정말 저장하시겠습니까? 실제 서비스에 즉시 반영됩니다. (다시 누르면 저장됩니다)"
              warningClassName="w-full rounded-lg border border-rose-900/60 bg-rose-950/20 p-2 text-xs font-semibold text-rose-300"
              idleLabel="저장"
              confirmLabel="확인(최종 저장)"
              pendingLabel="저장 중..."
              idleButtonClassName="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
              confirmButtonClassName="rounded-lg bg-rose-700 px-3 py-1.5 text-xs font-medium text-white hover:bg-rose-600 disabled:opacity-50"
              showCancelWhenIdle
              cancelButtonClassName="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
              buttonWrapperClassName="contents"
              onCancel={() => {
                setEditing(false);
                setConfirming(false);
              }}
            />
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-200">{productName}</td>
      <td className="px-4 py-3 text-slate-300">{gradeName}</td>
      <td className="px-4 py-3 text-slate-400">{REWARD_TYPE_LABEL[pool.rewardType] ?? pool.rewardType}</td>
      <td className="px-4 py-3 text-slate-400">{pool.rewardAmount ?? "-"}</td>
      <td className="px-4 py-3 text-slate-300">{pool.probability}%</td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800"
            >
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={pool.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-900 px-3 py-1 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
