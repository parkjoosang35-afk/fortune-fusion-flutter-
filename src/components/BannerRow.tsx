"use client";

import { useActionState, useState } from "react";
import {
  updateBanner,
  deleteBanner,
  toggleBannerActive,
  type BannerFormState,
} from "@/app/actions/banners";
import ImageUploadField from "@/components/ImageUploadField";

interface BannerRowProps {
  banner: {
    id: number;
    title: string;
    imageUrl: string | null;
    linkUrl: string | null;
    adType: string;
    adScript: string | null;
    positionCode: string;
    sortOrder: number;
    isActive: boolean;
    startAt: Date | null;
    endAt: Date | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: BannerFormState = {};

const POSITION_LABEL: Record<string, string> = {
  home_top: "홈 상단",
  home_middle: "홈 중단",
  home_bottom: "홈 하단",
};

function toLocalInputValue(d: Date | null): string {
  if (!d) return "";
  return d.toISOString().slice(0, 16);
}

function formatDate(d: Date | null): string {
  if (!d) return "-";
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function BannerRow({ banner, canWrite, canDelete }: BannerRowProps) {
  const [editing, setEditing] = useState(false);
  const [adType, setAdType] = useState<"image" | "script">(
    banner.adType === "script" ? "script" : "image"
  );
  const [updateState, updateAction, updatePending] = useActionState(updateBanner, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteBanner, initialState);
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleBannerActive,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-800/60 bg-slate-800/30">
        <td colSpan={7} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={banner.id} />
            <div className="flex w-full gap-4 rounded-lg border border-slate-700 bg-slate-800/60 px-3 py-1.5 text-xs text-slate-300">
              <span className="text-slate-500">광고 유형</span>
              <label className="flex items-center gap-1">
                <input
                  type="radio"
                  name="adType"
                  value="image"
                  checked={adType === "image"}
                  onChange={() => setAdType("image")}
                  className="accent-indigo-500"
                />
                이미지+링크
              </label>
              <label className="flex items-center gap-1">
                <input
                  type="radio"
                  name="adType"
                  value="script"
                  checked={adType === "script"}
                  onChange={() => setAdType("script")}
                  className="accent-indigo-500"
                />
                광고소스(스크립트)
              </label>
            </div>
            <input
              type="text"
              name="title"
              defaultValue={banner.title}
              className="w-44 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <select
              name="positionCode"
              defaultValue={banner.positionCode}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            >
              <option value="home_top">홈 상단</option>
              <option value="home_middle">홈 중단</option>
              <option value="home_bottom">홈 하단</option>
            </select>
            <input
              type="number"
              name="sortOrder"
              defaultValue={banner.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            {adType === "image" ? (
              <>
                <ImageUploadField
                  name="imageUrl"
                  category="banners"
                  defaultValue={banner.imageUrl}
                  compact
                />
                <input
                  type="text"
                  name="linkUrl"
                  defaultValue={banner.linkUrl ?? ""}
                  placeholder="제휴 링크 URL(선택)"
                  className="w-52 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
                />
              </>
            ) : (
              <textarea
                name="adScript"
                defaultValue={banner.adScript ?? ""}
                rows={3}
                placeholder="제휴사 원본 광고 스크립트/iframe 코드"
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 font-mono text-xs text-white outline-none focus:border-indigo-500"
              />
            )}
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(banner.startAt)}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(banner.endAt)}
              className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white outline-none focus:border-indigo-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-300">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={banner.isActive}
                className="accent-indigo-500"
              />
              활성
            </label>
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
            {updateState.error && <p className="w-full text-xs text-red-400">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3">
        {banner.adType === "script" ? (
          <span className="inline-flex h-10 w-20 items-center justify-center rounded-md border border-dashed border-indigo-700 bg-indigo-950/40 text-[10px] text-indigo-300">
            &lt;script&gt;
          </span>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={banner.imageUrl ?? ""}
            alt={banner.title}
            className="h-10 w-20 rounded-md border border-slate-700 object-cover"
          />
        )}
      </td>
      <td className="px-4 py-3 text-slate-200">
        {banner.title}
        <span
          className={`ml-2 rounded-full px-1.5 py-0.5 text-[10px] ${
            banner.adType === "script"
              ? "bg-indigo-950/60 text-indigo-300"
              : "bg-slate-800 text-slate-400"
          }`}
        >
          {banner.adType === "script" ? "광고소스" : "이미지"}
        </span>
      </td>
      <td className="px-4 py-3 text-slate-300">
        {POSITION_LABEL[banner.positionCode] ?? banner.positionCode}
        <span className="ml-1 text-xs text-slate-500">#{banner.sortOrder}</span>
      </td>
      <td className="px-4 py-3">
        {banner.adType === "script" ? (
          <span
            className="block max-w-[240px] truncate font-mono text-xs text-slate-400"
            title={banner.adScript ?? ""}
          >
            {banner.adScript}
          </span>
        ) : banner.linkUrl ? (
          <a
            href={banner.linkUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="max-w-[220px] truncate text-indigo-400 underline hover:text-indigo-300"
            title={banner.linkUrl}
          >
            {banner.linkUrl}
          </a>
        ) : (
          <span className="text-slate-500">-</span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {formatDate(banner.startAt)}
        <br />
        {formatDate(banner.endAt)}
      </td>
      <td className="px-4 py-3">
        {banner.isActive ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">
            활성
          </span>
        ) : (
          <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
            비활성
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={banner.id} />
              <input type="hidden" name="isActive" value={(!banner.isActive).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-700 px-3 py-1 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50"
              >
                {banner.isActive ? "비활성으로" : "활성으로"}
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
              <input type="hidden" name="id" value={banner.id} />
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
