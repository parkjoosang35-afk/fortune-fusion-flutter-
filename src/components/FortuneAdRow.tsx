"use client";

// [신통방통 복주머니 광고 적립 시스템] 광고 목록 행. OpenPassAdSourceRow.tsx 패턴 재사용.
import { useActionState, useState, useTransition } from "react";
import {
  updateFortuneAd,
  deleteFortuneAd,
  toggleFortuneAdActive,
  type FortuneAdFormState,
} from "@/app/actions/fortune-ads";

export interface FortuneAdRowData {
  id: number;
  title: string;
  description: string | null;
  adType: string;
  imageUrl: string | null;
  videoUrl: string | null;
  externalUrl: string | null;
  adSourceHtml: string | null;
  rewardAmount: number;
  watchSeconds: number;
  isActive: boolean;
  startAt: Date | string | null;
  endAt: Date | string | null;
  priority: number;
  perUserDailyLimit: number;
  dailyLimitReward: number | null;
}

const AD_TYPE_LABELS: Record<string, string> = {
  image: "이미지",
  video: "동영상",
  external: "외부 광고",
  network: "광고플랫폼",
};

const initialState: FortuneAdFormState = {};

function toLocalInputValue(d: Date | string | null): string {
  if (!d) return "";
  const date = new Date(d);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function FortuneAdRow({
  ad,
  todayStats,
  canWrite,
  canDelete,
}: {
  ad: FortuneAdRowData;
  todayStats: { todayCount: number; todayReward: number };
  canWrite: boolean;
  canDelete: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateFortuneAd, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteFortuneAd, initialState);
  const [isTogglePending, startToggle] = useTransition();
  const [localActive, setLocalActive] = useState(ad.isActive);
  const [adType, setAdType] = useState(ad.adType);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={8} className="px-4 py-3">
          <form action={updateAction} className="grid grid-cols-1 gap-2 md:grid-cols-4">
            <input type="hidden" name="id" value={ad.id} />
            <input type="text" name="title" defaultValue={ad.title} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2" />
            <select
              name="adType"
              value={adType}
              onChange={(e) => setAdType(e.target.value)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {Object.entries(AD_TYPE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
            <input type="text" name="description" defaultValue={ad.description ?? ""} placeholder="설명" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            {adType === "image" && (
              <input type="text" name="imageUrl" defaultValue={ad.imageUrl ?? ""} placeholder="이미지 URL" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4" />
            )}
            {adType === "video" && (
              <input type="text" name="videoUrl" defaultValue={ad.videoUrl ?? ""} placeholder="동영상 URL" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4" />
            )}
            {adType === "external" && (
              <input type="text" name="externalUrl" defaultValue={ad.externalUrl ?? ""} placeholder="외부 광고 URL" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4" />
            )}
            {adType === "network" && (
              <textarea name="adSourceHtml" defaultValue={ad.adSourceHtml ?? ""} rows={2} placeholder="연동 스크립트/HTML" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-4" />
            )}

            <input type="number" name="rewardAmount" defaultValue={ad.rewardAmount} placeholder="1회 보상" min={1} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="watchSeconds" defaultValue={ad.watchSeconds} placeholder="최소 시청초" min={1} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="perUserDailyLimit" defaultValue={ad.perUserDailyLimit} placeholder="회원당 하루횟수" min={1} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="dailyLimitReward" defaultValue={ad.dailyLimitReward ?? ""} placeholder="하루 최대지급총량" min={0} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <input type="number" name="priority" defaultValue={ad.priority} placeholder="우선순위" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="datetime-local" name="startAt" defaultValue={toLocalInputValue(ad.startAt)} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="datetime-local" name="endAt" defaultValue={toLocalInputValue(ad.endAt)} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <div className="col-span-full flex flex-wrap items-center gap-3">
              <label className="flex items-center gap-2 text-xs text-slate-600"><input type="checkbox" name="isActive" defaultChecked={ad.isActive} className="accent-indigo-500" /> 활성</label>
              <button type="submit" disabled={updatePending} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50">저장</button>
              <button type="button" onClick={() => setEditing(false)} className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100">취소</button>
            </div>
            {updateState.error && <p className="col-span-full text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-700">
        {ad.title}
        {ad.description && <p className="mt-0.5 text-xs text-slate-500">{ad.description}</p>}
      </td>
      <td className="px-4 py-3 text-slate-500">{AD_TYPE_LABELS[ad.adType] ?? ad.adType}</td>
      <td className="px-4 py-3 text-slate-500">
        {ad.rewardAmount}개 / {ad.watchSeconds}s
      </td>
      <td className="px-4 py-3 text-slate-500">
        회원당 {ad.perUserDailyLimit}회/일
        <br />
        총 {ad.dailyLimitReward ?? "무제한"}개/일
      </td>
      <td className="px-4 py-3 text-slate-500">
        오늘 {todayStats.todayCount}회 / {todayStats.todayReward}개
      </td>
      <td className="px-4 py-3 text-slate-500">{ad.priority}</td>
      <td className="px-4 py-3">
        {canWrite ? (
          <button
            disabled={isTogglePending}
            onClick={() =>
              startToggle(async () => {
                const next = !localActive;
                setLocalActive(next);
                await toggleFortuneAdActive(ad.id, next);
              })
            }
            className={`rounded-full px-2 py-0.5 text-xs ${
              localActive ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"
            } disabled:opacity-50`}
          >
            {localActive ? "노출중" : "비노출"}
          </button>
        ) : localActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">노출중</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비노출</span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex gap-2">
          {canWrite && (
            <button onClick={() => setEditing(true)} className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100">
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={ad.id} />
              <button type="submit" disabled={deletePending} className="rounded-lg border border-red-300 px-3 py-1 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50">
                삭제
              </button>
            </form>
          )}
        </div>
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
