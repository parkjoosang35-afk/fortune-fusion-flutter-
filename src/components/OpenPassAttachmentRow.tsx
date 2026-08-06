"use client";

// 열림패스 첨부파일 목록 행. [사용자 요청] §6-2 표시 컬럼: 파일명/타입/용도/미리보기/크기/업로드일시/활성상태/연결상품
import { useActionState, useState } from "react";
import {
  updateOpenPassAttachment,
  deleteOpenPassAttachment,
  type AttachmentFormState,
} from "@/app/actions/open-pass-attachments";
import {
  ATTACHMENT_FILE_TYPES,
  ATTACHMENT_FILE_TYPE_LABELS,
  ATTACHMENT_PURPOSES,
  ATTACHMENT_PURPOSE_LABELS,
  type AttachmentFileType,
} from "@/lib/open-pass-constants";
import OpenPassAttachmentUploadField from "@/components/OpenPassAttachmentUploadField";

export interface AttachmentRowData {
  id: number;
  fileName: string;
  fileType: string;
  purpose: string;
  fileUrl: string | null;
  thumbnailUrl: string | null;
  mimeType: string | null;
  fileSize: number | null;
  htmlContent: string | null;
  displayOrder: number;
  isActive: boolean;
  createdAt: Date | string;
}

const initialState: AttachmentFormState = {};

function formatFileSize(size: number | null): string {
  if (!size) return "-";
  if (size < 1024) return `${size}B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)}KB`;
  return `${(size / (1024 * 1024)).toFixed(1)}MB`;
}

function PreviewCell({ attachment }: { attachment: AttachmentRowData }) {
  if (attachment.fileType === "rich_text_html") {
    return <span className="text-xs text-slate-500">HTML 본문</span>;
  }
  if (!attachment.fileUrl) return <span className="text-xs text-slate-500">-</span>;
  if (attachment.fileType === "image" || attachment.fileType === "ad_fallback_image") {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={attachment.thumbnailUrl || attachment.fileUrl} alt={attachment.fileName} className="h-10 w-10 rounded border border-slate-300 object-cover" />;
  }
  if (attachment.fileType === "video" || attachment.fileType === "ad_fallback_video") {
    return <video src={attachment.fileUrl} className="h-10 w-16 rounded border border-slate-300 object-cover" muted />;
  }
  return (
    <a href={attachment.fileUrl} target="_blank" rel="noreferrer" className="text-xs text-indigo-800 hover:underline">
      {attachment.fileType === "document" ? "PDF 보기" : "링크 열기"}
    </a>
  );
}

export default function OpenPassAttachmentRow({
  attachment,
  linkedProductCount,
  canWrite,
  canDelete,
}: {
  attachment: AttachmentRowData;
  linkedProductCount: number;
  canWrite: boolean;
  canDelete: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [editFileType, setEditFileType] = useState<AttachmentFileType>(attachment.fileType as AttachmentFileType);
  const [updateState, updateAction, updatePending] = useActionState(updateOpenPassAttachment, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteOpenPassAttachment, initialState);

  if (editing) {
    return (
      <tr className="border-b border-slate-200/60 bg-white/30">
        <td colSpan={9} className="px-4 py-3">
          <form action={updateAction} className="grid grid-cols-1 gap-2 md:grid-cols-4">
            <input type="hidden" name="id" value={attachment.id} />
            <input
              type="text"
              name="fileName"
              defaultValue={attachment.fileName}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />
            <select
              name="fileType"
              value={editFileType}
              onChange={(e) => setEditFileType(e.target.value as AttachmentFileType)}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {ATTACHMENT_FILE_TYPES.map((t) => (
                <option key={t} value={t}>
                  {ATTACHMENT_FILE_TYPE_LABELS[t]}
                </option>
              ))}
            </select>
            <select
              name="purpose"
              defaultValue={attachment.purpose}
              className="rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            >
              {ATTACHMENT_PURPOSES.map((p) => (
                <option key={p} value={p}>
                  {ATTACHMENT_PURPOSE_LABELS[p]}
                </option>
              ))}
            </select>
            <label className="flex items-center gap-2 text-sm text-slate-600">
              <input type="checkbox" name="isActive" defaultChecked={attachment.isActive} className="accent-indigo-500" /> 활성화
            </label>

            <OpenPassAttachmentUploadField
              fileType={editFileType}
              defaultFileUrl={attachment.fileUrl}
              defaultThumbnailUrl={attachment.thumbnailUrl}
              defaultMimeType={attachment.mimeType}
              defaultFileSize={attachment.fileSize}
              defaultHtmlContent={attachment.htmlContent}
            />

            <input
              type="number"
              name="displayOrder"
              defaultValue={attachment.displayOrder}
              className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-sm text-slate-900 outline-none focus:border-indigo-500"
            />

            <div className="col-span-full flex gap-2">
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
                className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100"
              >
                취소
              </button>
            </div>
            {updateState.error && <p className="col-span-full text-xs text-red-700">{updateState.error}</p>}
          </form>
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-200/60 hover:bg-slate-100/40">
      <td className="px-4 py-3 text-slate-700">{attachment.fileName}</td>
      <td className="px-4 py-3 text-slate-500">{ATTACHMENT_FILE_TYPE_LABELS[attachment.fileType as AttachmentFileType] ?? attachment.fileType}</td>
      <td className="px-4 py-3 text-slate-500">{ATTACHMENT_PURPOSE_LABELS[attachment.purpose as keyof typeof ATTACHMENT_PURPOSE_LABELS] ?? attachment.purpose}</td>
      <td className="px-4 py-3">
        <PreviewCell attachment={attachment} />
      </td>
      <td className="px-4 py-3 text-slate-500">{formatFileSize(attachment.fileSize)}</td>
      <td className="px-4 py-3 text-slate-500 text-xs">{new Date(attachment.createdAt).toLocaleString("ko-KR")}</td>
      <td className="px-4 py-3">
        {attachment.isActive ? (
          <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700">활성</span>
        ) : (
          <span className="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500">비활성</span>
        )}
      </td>
      <td className="px-4 py-3 text-slate-500">
        {linkedProductCount > 0 ? (
          <span className="rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-700">{linkedProductCount}개 상품 연결</span>
        ) : (
          <span className="text-xs text-slate-500">연결 없음</span>
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
              <input type="hidden" name="id" value={attachment.id} />
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
        {deleteState.error && <p className="mt-1 text-xs text-red-700">{deleteState.error}</p>}
      </td>
    </tr>
  );
}
