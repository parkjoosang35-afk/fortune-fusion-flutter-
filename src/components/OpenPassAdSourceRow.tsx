"use client";

// 열림패스 광고소스 목록 행. [사용자 요청] §6-3
import { useActionState, useState, useTransition } from "react";
import {
  updateOpenPassAdSource,
  deleteOpenPassAdSource,
  toggleOpenPassAdSourceActive,
  type AdSourceFormState,
} from "@/app/actions/open-pass-ad-sources";
import { AD_SOURCE_TYPES, AD_SOURCE_TYPE_LABELS, type AdSourceType } from "@/lib/open-pass-constants";

export interface AdSourceRowData {
  id: number;
  sourceName: string;
  sourceType: string;
  networkName: string | null;
  adUnitId: string | null;
  placementId: string | null;
  rewardType: string | null;
  rewardValue: number | null;
  cooldownSeconds: number;
  dailyLimit: number | null;
  failoverEnabled: boolean;
  fallbackAttachmentId: number | null;
  testModeEnabled: boolean;
  isActive: boolean;
  priority: number;
  startAt: Date | string | null;
  endAt: Date | string | null;
  simulatedDurationSeconds: number | null;
  failMode: string | null;
}

const initialState: AdSourceFormState = {};

function toLocalInputValue(d: Date | string | null): string {
  if (!d) return "";
  const date = new Date(d);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function OpenPassAdSourceRow({
  adSource,
  linkedProductCount,
  attachmentOptions,
  canWrite,
  canDelete,
}: {
  adSource: AdSourceRowData;
  linkedProductCount: number;
  attachmentOptions: Array<{ id: number; fileName: string }>;
  canWrite: boolean;
  canDelete: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateOpenPassAdSource, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteOpenPassAdSource, initialState);
  const [isTogglePending, startToggle] = useTransition();
  const [localActive, setLocalActive] = useState(adSource.isActive);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={9} className="px-4 py-3">
          <form action={updateAction} className="grid grid-cols-1 gap-2 md:grid-cols-4">
            <input type="hidden" name="id" value={adSource.id} />
            <input type="text" name="sourceName" defaultValue={adSource.sourceName} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2" />
            <select name="sourceType" defaultValue={adSource.sourceType} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500">
              {AD_SOURCE_TYPES.map((t) => (
                <option key={t} value={t}>{AD_SOURCE_TYPE_LABELS[t as AdSourceType]}</option>
              ))}
            </select>
            <input type="text" name="networkName" defaultValue={adSource.networkName ?? ""} placeholder="네트워크명" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <input type="text" name="adUnitId" defaultValue={adSource.adUnitId ?? ""} placeholder="adUnitId" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2" />
            <input type="text" name="placementId" defaultValue={adSource.placementId ?? ""} placeholder="placementId" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="text" name="rewardType" defaultValue={adSource.rewardType ?? ""} placeholder="rewardType" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <input type="number" name="rewardValue" defaultValue={adSource.rewardValue ?? ""} placeholder="rewardValue" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="cooldownSeconds" defaultValue={adSource.cooldownSeconds} placeholder="쿨다운(초)" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="dailyLimit" defaultValue={adSource.dailyLimit ?? ""} placeholder="일일제한" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="priority" defaultValue={adSource.priority} placeholder="우선순위" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <select name="fallbackAttachmentId" defaultValue={adSource.fallbackAttachmentId ?? ""} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2">
              <option value="">fallback 없음</option>
              {attachmentOptions.map((a) => (
                <option key={a.id} value={a.id}>{a.fileName}</option>
              ))}
            </select>
            <input type="datetime-local" name="startAt" defaultValue={toLocalInputValue(adSource.startAt)} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="datetime-local" name="endAt" defaultValue={toLocalInputValue(adSource.endAt)} className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="number" name="simulatedDurationSeconds" defaultValue={adSource.simulatedDurationSeconds ?? 4} min={1} max={60} placeholder="[테스트] 가짜 시청시간(초)" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />
            <input type="text" name="failMode" defaultValue={adSource.failMode ?? ""} placeholder="[테스트] 실패사유" className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500" />

            <div className="col-span-full flex flex-wrap items-center gap-3">
              <label className="flex items-center gap-2 text-xs text-slate-600"><input type="checkbox" name="failoverEnabled" defaultChecked={adSource.failoverEnabled} className="accent-indigo-500" /> failover</label>
              <label className="flex items-center gap-2 text-xs text-slate-600"><input type="checkbox" name="testModeEnabled" defaultChecked={adSource.testModeEnabled} className="accent-indigo-500" /> 테스트모드</label>
              <label className="flex items-center gap-2 text-xs text-slate-600"><input type="checkbox" name="isActive" defaultChecked={adSource.isActive} className="accent-indigo-500" /> 활성</label>
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
        {adSource.sourceName}
        {adSource.testModeEnabled && <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700">테스트</span>}
      </td>
      <td className="px-4 py-3 text-slate-500">
        {AD_SOURCE_TYPE_LABELS[adSource.sourceType as AdSourceType] ?? adSource.sourceType}
      </td>
      <td className="px-4 py-3 text-slate-500 text-xs">{adSource.adUnitId || "-"}</td>
      <td className="px-4 py-3 text-slate-500">{adSource.cooldownSeconds}s / {adSource.dailyLimit ?? "무제한"}회</td>
      <td className="px-4 py-3 text-slate-500">{adSource.priority}</td>
      <td className="px-4 py-3 text-slate-500">
        {adSource.fallbackAttachmentId ? (
          <span className="rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-700">설정됨</span>
        ) : (
          <span className="text-xs text-slate-500">미설정</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-500">
        {linkedProductCount > 0 ? (
          <span className="rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-700">{linkedProductCount}개 상품</span>
        ) : (
          <span className="text-xs text-slate-500">연결 없음</span>
        )}
      </td>
      <td className="px-4 py-3">
        {canWrite ? (
          <button
            disabled={isTogglePending}
            onClick={() =>
              startToggle(async () => {
                const next = !localActive;
                setLocalActive(next);
                await toggleOpenPassAdSourceActive(adSource.id, next);
              })
            }
            className={`rounded-full px-2 py-0.5 text-xs ${
              localActive ? "bg-emerald-100 text-emerald-700" : "bg-white text-slate-500"
            } disabled:opacity-50`}
          >
            {localActive ? "활성" : "비활성"}
          </button>
        ) : localActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
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
              <input type="hidden" name="id" value={adSource.id} />
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
