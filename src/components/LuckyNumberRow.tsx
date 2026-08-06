"use client";

// "오늘의 행운숫자" 관리자 콘텐츠 테이블 행.
// [사용자 요청] 광고(banners)가 아닌 별도 기능 — BannerRow.tsx 구조를 참고하되
// positionCode(노출 위치) 관련 필드는 모두 제거하고, adType 2종 대신 contentType 3종으로 확장.
import { useActionState, useState } from "react";
import {
  updateLuckyNumberContent,
  deleteLuckyNumberContent,
  toggleLuckyNumberContentActive,
  type LuckyNumberFormState,
} from "@/app/actions/luckyNumberContent";
import MediaUploadField from "@/components/MediaUploadField";

interface LuckyNumberRowProps {
  content: {
    id: number;
    title: string;
    contentType: string;
    imageUrl: string | null;
    videoUrl: string | null;
    script: string | null;
    caption: string | null;
    sortOrder: number;
    isActive: boolean;
    startAt: Date | null;
    endAt: Date | null;
  };
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: LuckyNumberFormState = {};

const CONTENT_TYPE_LABEL: Record<string, string> = {
  image: "이미지",
  video: "영상",
  script: "소스",
};

function toLocalInputValue(d: Date | null): string {
  if (!d) return "";
  return d.toISOString().slice(0, 16);
}

function formatDate(d: Date | null): string {
  if (!d) return "-";
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function LuckyNumberRow({ content, canWrite, canDelete }: LuckyNumberRowProps) {
  const [editing, setEditing] = useState(false);
  const [contentType, setContentType] = useState<"image" | "video" | "script">(
    content.contentType === "video" || content.contentType === "script"
      ? (content.contentType as "video" | "script")
      : "image"
  );
  const [updateState, updateAction, updatePending] = useActionState(
    updateLuckyNumberContent,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState(
    deleteLuckyNumberContent,
    initialState
  );
  const [toggleState, toggleAction, togglePending] = useActionState(
    toggleLuckyNumberContentActive,
    initialState
  );

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={5} className="px-4 py-3">
          <form action={updateAction} className="flex flex-wrap items-center gap-2">
            <input type="hidden" name="id" value={content.id} />
            <div className="flex w-full gap-4 rounded-lg border border-slate-300 bg-white/60 px-3 py-1.5 text-xs text-slate-600">
              <span className="text-slate-500">콘텐츠 유형</span>
              <label className="flex items-center gap-1">
                <input
                  type="radio"
                  name="contentType"
                  value="image"
                  checked={contentType === "image"}
                  onChange={() => setContentType("image")}
                  className="accent-purple-500"
                />
                이미지
              </label>
              <label className="flex items-center gap-1">
                <input
                  type="radio"
                  name="contentType"
                  value="video"
                  checked={contentType === "video"}
                  onChange={() => setContentType("video")}
                  className="accent-purple-500"
                />
                영상
              </label>
              <label className="flex items-center gap-1">
                <input
                  type="radio"
                  name="contentType"
                  value="script"
                  checked={contentType === "script"}
                  onChange={() => setContentType("script")}
                  className="accent-purple-500"
                />
                소스
              </label>
            </div>
            <input
              type="text"
              name="title"
              defaultValue={content.title}
              className="w-44 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="number"
              name="sortOrder"
              defaultValue={content.sortOrder}
              min={0}
              className="w-20 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="text"
              name="caption"
              defaultValue={content.caption ?? ""}
              placeholder="캡션(선택)"
              className="w-40 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            {contentType === "image" && (
              <MediaUploadField
                name="imageUrl"
                category="lucky-number"
                kind="image"
                defaultValue={content.imageUrl}
                className="w-full"
              />
            )}
            {contentType === "video" && (
              <MediaUploadField
                name="videoUrl"
                category="lucky-number"
                kind="video"
                defaultValue={content.videoUrl}
                className="w-full"
              />
            )}
            {contentType === "script" && (
              <textarea
                name="script"
                defaultValue={content.script ?? ""}
                rows={3}
                placeholder="HTML/스크립트 코드"
                className="w-full rounded-lg border border-slate-300 bg-white px-2 py-1 font-mono text-xs text-slate-900 outline-none focus:border-purple-500"
              />
            )}
            <input
              type="datetime-local"
              name="startAt"
              defaultValue={toLocalInputValue(content.startAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <input
              type="datetime-local"
              name="endAt"
              defaultValue={toLocalInputValue(content.endAt)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-purple-500"
            />
            <label className="flex items-center gap-1 text-xs text-slate-600">
              <input
                type="checkbox"
                name="isActive"
                defaultChecked={content.isActive}
                className="accent-purple-500"
              />
              활성
            </label>
            <button
              type="submit"
              disabled={updatePending}
              className="rounded-lg bg-purple-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-purple-500 disabled:opacity-50"
            >
              저장
            </button>
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100"
            >
              취소
            </button>
            {updateState.error && <p className="w-full text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3">
        {content.contentType === "script" ? (
          <span className="inline-flex h-10 w-20 items-center justify-center rounded-md border border-dashed border-purple-300 bg-purple-100 text-[10px] text-purple-800">
            &lt;script&gt;
          </span>
        ) : content.contentType === "video" ? (
          <video
            src={content.videoUrl ?? ""}
            className="h-10 w-20 rounded-md border border-slate-300 object-cover"
            muted
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={content.imageUrl ?? ""}
            alt={content.title}
            className="h-10 w-20 rounded-md border border-slate-300 object-cover"
          />
        )}
      </td>
      <td className="px-4 py-3 text-slate-700">
        {content.title}
        <span className="ml-2 rounded-full bg-white px-1.5 py-0.5 text-[10px] text-slate-500">
          {CONTENT_TYPE_LABEL[content.contentType] ?? content.contentType}
        </span>
        <span className="ml-1 text-xs text-slate-500">#{content.sortOrder}</span>
        {content.caption && (
          <p className="mt-0.5 max-w-[200px] truncate text-xs text-slate-500" title={content.caption}>
            {content.caption}
          </p>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">
        {formatDate(content.startAt)}
        <br />
        {formatDate(content.endAt)}
      </td>
      <td className="px-4 py-3">
        {content.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">
            활성
          </span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">
            비활성
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {canWrite && (
            <form action={toggleAction}>
              <input type="hidden" name="id" value={content.id} />
              <input type="hidden" name="isActive" value={(!content.isActive).toString()} />
              <button
                type="submit"
                disabled={togglePending}
                className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100 disabled:opacity-50"
              >
                {content.isActive ? "비활성으로" : "활성으로"}
              </button>
            </form>
          )}
          {canWrite && (
            <button
              onClick={() => setEditing(true)}
              className="rounded-lg border border-slate-300 px-3 py-1 text-xs text-slate-600 hover:bg-slate-100"
            >
              수정
            </button>
          )}
          {canDelete && (
            <form action={deleteAction}>
              <input type="hidden" name="id" value={content.id} />
              <button
                type="submit"
                disabled={deletePending}
                className="rounded-lg border border-red-300 px-3 py-1 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50"
              >
                삭제
              </button>
            </form>
          )}
        </div>
        {toggleState.error && <p className="mt-1 text-xs text-red-700">{toggleState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
