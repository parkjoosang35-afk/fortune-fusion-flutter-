"use client";

// [사용자 요청: "오늘의 행운숫자" 관리자 콘텐츠 - 이미지/영상 첨부 지원]
// ImageUploadField(이미지 전용)를 그대로 재사용하지 않고, contentType에 따라
// accept 속성(이미지 vs 영상 MIME)을 동적으로 바꾸는 전용 필드를 별도로 둔다.
import { useRef, useState } from "react";

interface MediaUploadFieldProps {
  name: string;
  category: string;
  kind: "image" | "video";
  defaultValue?: string | null;
  className?: string;
  placeholder?: string;
}

const IMAGE_ACCEPT = "image/jpeg,image/jpg,image/png,image/webp,image/gif";
const VIDEO_ACCEPT = "video/mp4,video/webm,video/quicktime";

export default function MediaUploadField({
  name,
  category,
  kind,
  defaultValue,
  className,
  placeholder,
}: MediaUploadFieldProps) {
  const [url, setUrl] = useState(defaultValue ?? "");
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    setError(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      fd.append("category", category);
      const res = await fetch("/api/upload", { method: "POST", body: fd });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "업로드에 실패했습니다.");
        return;
      }
      setUrl(data.url);
    } catch {
      setError("업로드 중 오류가 발생했습니다.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  return (
    <div className={`flex flex-col gap-1 ${className ?? ""}`}>
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          name={name}
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder={placeholder ?? (kind === "video" ? "영상 URL" : "이미지 URL")}
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-indigo-500 md:col-span-2"
        />
        <label
          className={`cursor-pointer rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 ${
            uploading ? "pointer-events-none opacity-50" : ""
          }`}
        >
          {uploading ? "업로드 중..." : "파일 선택"}
          <input
            ref={fileInputRef}
            type="file"
            accept={kind === "video" ? VIDEO_ACCEPT : IMAGE_ACCEPT}
            onChange={handleFileChange}
            className="hidden"
            disabled={uploading}
          />
        </label>
        {url && kind === "image" && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={url} alt="미리보기" className="h-9 w-9 rounded border border-slate-300 object-cover" />
        )}
        {url && kind === "video" && (
          <video src={url} className="h-9 w-16 rounded border border-slate-300 object-cover" muted />
        )}
      </div>
      {error && <p className="text-xs text-red-700">{error}</p>}
    </div>
  );
}
