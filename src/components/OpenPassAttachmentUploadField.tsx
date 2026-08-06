"use client";

// 열림패스 첨부파일 업로드 위젯.
// [사용자 요청: 열림패스 관리자 첨부파일 관리] §3/§6-2/§12
// ImageUploadField/MediaUploadField와 동일한 "먼저 /api/upload로 업로드 → 반환된 URL을
// hidden text input에 채워 Server Action이 formData.get(...)으로 그대로 읽게 한다" 패턴을
// 따르되, fileType(image/video/document/external_link/rich_text_html/ad_fallback_*)에 따라
// - 파일 업로드가 필요한 유형: 파일선택 버튼 + accept 동적 지정 + 업로드 후 mimeType/fileSize도
//   함께 hidden input에 채워 Server Action이 "파일 목적을 임의 추정"하지 않고 실제 업로드
//   메타데이터를 그대로 저장하게 한다(§15 "앱에서 파일 목적을 임의 추정 금지"와 동일한 취지로,
//   관리자 쪽도 추정이 아니라 실제 값을 저장).
// - external_link: URL 텍스트 입력만
// - rich_text_html: HTML 본문 textarea만 (파일 업로드 없음)
import { useRef, useState } from "react";
import type { AttachmentFileType } from "@/lib/open-pass-constants";

const ACCEPT_MAP: Record<string, string> = {
  image: "image/jpeg,image/jpg,image/png,image/webp,image/gif",
  video: "video/mp4,video/webm,video/quicktime",
  document: "application/pdf",
  ad_fallback_image: "image/jpeg,image/jpg,image/png,image/webp,image/gif",
  ad_fallback_video: "video/mp4,video/webm,video/quicktime",
};

interface UploadResult {
  url: string;
  mimeType: string;
  fileSize: number;
  isVideo?: boolean;
  isDocument?: boolean;
}

interface Props {
  fileType: AttachmentFileType;
  defaultFileUrl?: string | null;
  defaultThumbnailUrl?: string | null;
  defaultMimeType?: string | null;
  defaultFileSize?: number | null;
  defaultHtmlContent?: string | null;
}

export default function OpenPassAttachmentUploadField({
  fileType,
  defaultFileUrl,
  defaultThumbnailUrl,
  defaultMimeType,
  defaultFileSize,
  defaultHtmlContent,
}: Props) {
  const [url, setUrl] = useState(defaultFileUrl ?? "");
  const [thumbnailUrl, setThumbnailUrl] = useState(defaultThumbnailUrl ?? "");
  const [mimeType, setMimeType] = useState(defaultMimeType ?? "");
  const [fileSize, setFileSize] = useState<number | "">(defaultFileSize ?? "");
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const isHtml = fileType === "rich_text_html";
  const isLink = fileType === "external_link";
  const isVideoKind = fileType === "video" || fileType === "ad_fallback_video";
  const isImageKind = fileType === "image" || fileType === "ad_fallback_image";

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      fd.append("category", "open-pass");
      const res = await fetch("/api/upload", { method: "POST", body: fd });
      const data: UploadResult & { error?: string } = await res.json();
      if (!res.ok) {
        setError(data.error ?? "업로드에 실패했습니다.");
        return;
      }
      setUrl(data.url);
      setMimeType(data.mimeType ?? file.type);
      setFileSize(data.fileSize ?? file.size);
      if (isImageKind) setThumbnailUrl(data.url);
    } catch {
      setError("업로드 중 오류가 발생했습니다.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  if (isHtml) {
    return (
      <div className="flex flex-col gap-1 md:col-span-2">
        <textarea
          name="htmlContent"
          defaultValue={defaultHtmlContent ?? ""}
          rows={3}
          placeholder="안내용 HTML 본문을 입력하세요 (예: <p>이용 안내...</p>)"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
        {/* rich_text_html은 fileUrl이 없으므로 Server Action이 필수값으로 보지 않도록 빈 값 유지 */}
        <input type="hidden" name="fileUrl" value="" />
        <input type="hidden" name="mimeType" value="" />
        <input type="hidden" name="fileSize" value="" />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-1 md:col-span-2">
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          name="fileUrl"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder={isLink ? "https:// 로 시작하는 외부 링크 URL" : "업로드 후 URL이 자동으로 입력됩니다"}
          required
          className="min-w-0 flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500"
        />
        {!isLink && (
          <label
            className={`cursor-pointer rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 ${
              uploading ? "pointer-events-none opacity-50" : ""
            }`}
          >
            {uploading ? "업로드 중..." : "파일 선택"}
            <input
              ref={fileInputRef}
              type="file"
              accept={ACCEPT_MAP[fileType] ?? "*/*"}
              onChange={handleFileChange}
              className="hidden"
              disabled={uploading}
            />
          </label>
        )}
        {url && isImageKind && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={url} alt="미리보기" className="h-9 w-9 rounded border border-slate-300 object-cover" />
        )}
        {url && isVideoKind && (
          <video src={url} className="h-9 w-16 rounded border border-slate-300 object-cover" muted />
        )}
        {url && fileType === "document" && (
          <a
            href={url}
            target="_blank"
            rel="noreferrer"
            className="rounded border border-slate-300 px-2 py-1 text-xs text-indigo-800 hover:bg-slate-100"
          >
            PDF 열기
          </a>
        )}
      </div>
      <input type="hidden" name="mimeType" value={mimeType} />
      <input type="hidden" name="fileSize" value={fileSize} />
      <input type="hidden" name="thumbnailUrl" value={thumbnailUrl} />
      {error && <p className="text-xs text-red-700">{error}</p>}
    </div>
  );
}
