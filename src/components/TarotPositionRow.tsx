"use client";

// [신통방통 타로 65종 주제 연동 지시서 - ④ 관리자 CMS]
// 포지션(카드 자리) 1개 행 — 포지션명/해석목적만 인라인 편집. topicId/spreadType/
// positionIndex는 unique key라서 고정(재배치 불가), TarotCardRow.tsx와 동일한
// "editing 토글 + colSpan 폼" 패턴을 재사용한다. 삭제는 지원하지 않는다(65개 주제의
// 고정 스켈레톤이므로 개수를 바꾸면 route.ts의 positionMetas 매핑이 깨짐).
import { useActionState, useState } from "react";
import { updateTarotPosition, type TarotTopicActionState } from "@/app/actions/tarot-topics";

const initialState: TarotTopicActionState = {};

interface Props {
  position: {
    id: number;
    positionIndex: number;
    positionName: string;
    positionPurpose: string;
  };
  topicKey: string;
  canWrite: boolean;
}

export default function TarotPositionRow({ position, topicKey, canWrite }: Props) {
  const [editing, setEditing] = useState(false);
  const [state, action, pending] = useActionState(updateTarotPosition, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={3} className="px-3 py-3">
          <form
            action={async (formData) => {
              await action(formData);
              setEditing(false);
            }}
            className="space-y-2"
          >
            <input type="hidden" name="id" value={position.id} />
            <input type="hidden" name="topicKey" value={topicKey} />
            <input
              type="text"
              name="positionName"
              defaultValue={position.positionName}
              required
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <textarea
              name="positionPurpose"
              defaultValue={position.positionPurpose}
              required
              rows={2}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            {state.error && <p className="text-sm text-red-700">{state.error}</p>}
            <div className="flex gap-2">
              <button
                type="submit"
                disabled={pending}
                className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-indigo-500 disabled:opacity-50"
              >
                {pending ? "저장 중..." : "저장"}
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 transition hover:bg-slate-100"
              >
                취소
              </button>
            </div>
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-3 py-2 text-xs text-slate-500">#{position.positionIndex + 1}</td>
      <td className="px-3 py-2 font-medium text-slate-900">{position.positionName}</td>
      <td className="px-3 py-2 text-slate-500">
        <div className="flex items-start justify-between gap-2">
          <p className="line-clamp-2">{position.positionPurpose}</p>
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="shrink-0 rounded-lg border border-slate-300 px-2 py-1 text-xs text-slate-600 transition hover:bg-slate-100"
            >
              편집
            </button>
          )}
        </div>
      </td>
    </tr>
  );
}
