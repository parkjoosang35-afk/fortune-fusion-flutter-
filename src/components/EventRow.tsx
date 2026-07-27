"use client";

import { useActionState, useState } from "react";
import {
  updateEvent,
  deleteEvent,
  toggleEventActive,
  type EventFormState,
} from "@/app/actions/events";
import ImageUploadField from "@/components/ImageUploadField";

const EVENT_TYPE_LABEL: Record<string, string> = {
  attendance_bonus: "출석 보너스",
  roulette: "룰렛",
  special_mission: "특별 미션",
};

interface EventRowProps {
  event: {
    id: number;
    title: string;
    imageUrl: string | null;
    eventType: string;
    config: string;
    startAt: Date;
    endAt: Date;
    isActive: boolean;
  };
  participationCount: number;
  claimedCount: number;
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: EventFormState = {};

function toLocalInputValue(d: Date): string {
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
}

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 16).replace("T", " ");
}

export default function EventRow({
  event,
  participationCount,
  claimedCount,
  canWrite,
  canDelete,
}: EventRowProps) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateEvent, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteEvent, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleEventActive,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-col gap-2">
            <input type="hidden" name="id" value={event.id} />
            <div className="flex flex-wrap gap-2">
              <input
                type="text"
                name="title"
                defaultValue={event.title}
                className="w-64 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              />
              <select
                name="eventType"
                defaultValue={event.eventType}
                className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              >
                <option value="attendance_bonus">출석 보너스</option>
                <option value="roulette">룰렛</option>
                <option value="special_mission">특별 미션</option>
              </select>
              <label className="flex items-center gap-1 text-xs text-slate-300">
                <input
                  type="checkbox"
                  name="isActive"
                  defaultChecked={event.isActive}
                  className="accent-indigo-500"
                />
                활성화
              </label>
            </div>
            <ImageUploadField
              name="imageUrl"
              category="events"
              defaultValue={event.imageUrl}
              placeholder="배너 이미지 URL (선택)"
              compact
            />
            <div className="flex flex-wrap gap-2">
              <input
                type="datetime-local"
                name="startAt"
                defaultValue={toLocalInputValue(event.startAt)}
                className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              />
              <input
                type="datetime-local"
                name="endAt"
                defaultValue={toLocalInputValue(event.endAt)}
                className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
              />
            </div>
            <textarea
              name="config"
              defaultValue={event.config}
              rows={5}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 font-mono text-xs text-white outline-none focus:border-indigo-500"
            />
            <div className="flex items-center gap-2">
              <button
                type="submit"
                disabled={updatePending}
                className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
              >
                저장
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800"
              >
                취소
              </button>
            </div>
            {updateState.error && <p className="text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3">
        <div className="font-medium text-slate-200">{event.title}</div>
        <p className="mt-1 text-xs text-slate-500">
          {formatDate(event.startAt)} ~ {formatDate(event.endAt)}
        </p>
      </td>
      <td className="px-4 py-3">
        <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-300">
          {EVENT_TYPE_LABEL[event.eventType] ?? event.eventType}
        </span>
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {event.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-emerald-400">
            활성
          </span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-slate-400">비활성</span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-400">
        참여 {participationCount}명 · 지급완료 {claimedCount}명
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={event.id} />
              <input type="hidden" name="isActive" value={(!event.isActive).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50"
              >
                {event.isActive ? "비활성화" : "활성화"}
              </button>
            </form>
          )}
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
              <input type="hidden" name="id" value={event.id} />
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
        {toggleState.error && <p className="mt-1 text-xs text-red-400">{toggleState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
